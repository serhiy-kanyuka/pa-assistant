# Personal Assistant — Architecture

## Overview

Personal Assistant is a web-based system for submitting commands and files to named projects. It runs on AWS serverless infrastructure under the domain `pa.kanyuka.info`, with Google OAuth for access control and S3 with KMS encryption for persistent storage. Files are accessible from multiple devices via rclone mount.

## System Diagram

```
 Ubuntu Laptop             MacBook Air             Web Portal
 ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐
 │~/PA-Projects/│    │~/PA-Projects/│    │ pa.kanyuka.info      │
 │ projects/    │    │ projects/    │    │  → API Gateway       │
 │ (rclone      │    │ (rclone      │    │  → Lambda            │
 │  VFS cache)  │    │  VFS cache)  │    │                      │
 └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘
        │ HTTPS              │ HTTPS                 │ boto3
        └────────┬───────────┴───────────────────────┘
                 │
          ┌──────▼──────────────────┐
          │  S3: pa-kanyuka-info-data│
          │  SSE-KMS encrypted       │
          │  Versioning enabled      │
          │  Public access blocked   │
          └─────────────────────────┘

         pa.kanyuka.info        api.pa.kanyuka.info
              │                         │
       ┌──────▼──────┐          ┌──────▼──────────┐
       │ CloudFront  │          │  API Gateway    │
       └──────┬──────┘          └──────┬──────────┘
              │                        │
       ┌──────▼──────┐          ┌──────▼──────────┐
       │ S3 Frontend │          │  Lambda         │
       │ (static)    │          │  Python 3.12    │
       └─────────────┘          └─────────────────┘
```

## Components

### Frontend (pa.kanyuka.info)

Static single-page application served via S3 + CloudFront.

| File | Purpose |
|------|---------|
| `index.html` | Page structure, Google Sign-In widget |
| `styles.css` | Dark theme UI |
| `app.js` | Auth flow, API calls, file upload handling |

### API (api.pa.kanyuka.info)

HTTP API Gateway with custom domain, routing all requests to a single Lambda function.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `/api/health` | GET | No | Health check |
| `/api/projects` | GET | Yes | List project names from S3 |
| `/api/request` | POST | Yes | Submit command + files to a project |

### Lambda Function

Single Python 3.12 function using boto3 (included in Lambda runtime).

**Responsibilities:**
- Verify Google ID token (JWT decode + claim validation)
- Enforce email allowlist
- Parse multipart/form-data (file uploads)
- Write request files to S3 data bucket
- Update project's `REQUESTS.md` on S3

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `S3_DATA_BUCKET` | Data bucket name (`pa-kanyuka-info-data`) |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `ALLOWED_EMAILS` | Comma-separated allowlist |
| `ALLOWED_ORIGIN` | CORS origin (`https://pa.kanyuka.info`) |

### S3 Data Bucket

Persistent storage for all project files. Encrypted with KMS, versioning enabled, no public access.

```
s3://pa-kanyuka-info-data/
└── projects/
    ├── document-analysis/
    │   ├── REQUESTS.md
    │   ├── contracts/
    │   │   ├── contract-001.pdf       (added from laptop)
    │   │   └── contract-002.pdf       (added from laptop)
    │   ├── voice-notes/
    │   │   └── meeting.mp3            (uploaded via web portal)
    │   └── 1740000000_a1b2c3d4/
    │       ├── request.json           (created by Lambda)
    │       ├── command.txt
    │       └── scan.jpg               (uploaded via web portal)
    └── another-project/
        └── ...
```

### Client Access (rclone)

rclone mounts the S3 data bucket as a local folder with full VFS caching.

| Device | Mount point | Read speed | Write speed |
|--------|-------------|-----------|------------|
| Ubuntu laptop | `~/PA-Projects` | NVMe (cached) | NVMe (write-back cache) |
| MacBook Air | `~/PA-Projects` | NVMe (cached) | NVMe (write-back cache) |

### DNS & Certificates

| Record | Type | Target |
|--------|------|--------|
| `pa.kanyuka.info` | A (alias) | CloudFront distribution |
| `api.pa.kanyuka.info` | A (alias) | API Gateway regional domain |

| Cert | Region | Domains |
|------|--------|---------|
| CloudFront cert | us-east-1 | `pa.kanyuka.info`, `*.pa.kanyuka.info` |
| API cert | eu-central-1 | `api.pa.kanyuka.info` |

## Authentication Flow

```
Browser                    Google                   Lambda
  │                          │                        │
  ├─ Sign In click ─────────►│                        │
  │◄─── ID Token (JWT) ─────┤                        │
  │                          │                        │
  ├─ POST /api/request ──────┼───────────────────────►│
  │  Authorization: Bearer   │                        ├─ Verify JWT claims
  │  <id_token>              │                        ├─ Check email allowlist
  │                          │                        ├─ Write files to S3
  │◄─────────────────────────┼─── 200 OK ────────────┤
```

## Infrastructure as Code

All AWS resources are managed by Terraform in the `terraform/` directory.

| Resource | Count | Purpose |
|----------|-------|---------|
| S3 buckets | 2 | Frontend hosting + data storage |
| KMS key | 1 | S3 data encryption |
| Lambda | 1 function | Request handling |
| IAM role + policies | 1 role, 2 policies | Lambda execution, S3 access |
| IAM user | 1 | rclone client access |
| API Gateway | 1 API, 4 routes | HTTP routing |
| CloudFront distribution | 1 | CDN + HTTPS for frontend |
| ACM certificates | 2 | TLS for CloudFront + API GW |
| Route 53 records | 2 A + validation CNAMEs | DNS |

## Project Structure

```
personalassistant/
├── backend/
│   └── lambda_function.py          # Lambda handler (Python, boto3)
├── frontend/
│   ├── index.html                  # SPA with Google Sign-In
│   ├── styles.css                  # Dark theme
│   └── app.js                      # Auth, API calls, file upload
├── terraform/
│   ├── main.tf                     # All AWS resources
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Terraform outputs
│   └── terraform.tfvars.example    # Example configuration
├── scripts/
│   ├── deploy.sh                   # Full deploy
│   ├── update-frontend.sh          # Frontend-only deploy
│   ├── update-lambda.sh            # Lambda-only deploy
│   ├── setup-rclone-linux.sh       # rclone setup for Ubuntu
│   └── setup-rclone-macos.sh       # rclone setup for macOS
├── docs/
│   ├── SRS.md                      # Software Requirements Specification
│   ├── architecture.md             # This document
│   └── requestshistory.md          # Log of all requests
├── .cursor/rules/
│   └── log-interactions.mdc        # Auto-log Cursor interactions
├── .gitignore
├── INTERACTIONS.md                 # Cursor session log
└── README.md                       # Quick start
```
