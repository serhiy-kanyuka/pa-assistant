# Personal Assistant — Software Requirements Specification

**Version:** 2.0
**Date:** 2026-02-21
**Project:** Personal Assistant (`pa.kanyuka.info`)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [User Interface Requirements](#5-user-interface-requirements)
6. [API Specification](#6-api-specification)
7. [Data Model](#7-data-model)
8. [Architecture](#8-architecture)
9. [Infrastructure](#9-infrastructure)
10. [Security](#10-security)
11. [Client Access (rclone)](#11-client-access-rclone)
12. [Deployment](#12-deployment)
13. [Constraints and Assumptions](#13-constraints-and-assumptions)

---

## 1. Introduction

### 1.1 Purpose

Personal Assistant is a private web portal for submitting commands and files to named projects. It serves as a centralized interface for sending task requests — each containing a text command and optional file attachments — organized by project. All data is persisted on AWS S3 with KMS encryption and accessible from multiple devices.

### 1.2 Scope

The system consists of:
- A static web frontend hosted at `https://pa.kanyuka.info`
- A REST API at `https://api.pa.kanyuka.info`
- A Python Lambda function for request processing
- An S3 bucket with KMS encryption for persistent project and request storage
- Google OAuth 2.0 for authentication with email allowlist
- rclone mount on client devices (Ubuntu laptop, MacBook Air) for local file access

### 1.3 Definitions

| Term | Definition |
|------|-----------|
| **Project** | A named workspace that groups related requests. Stored as an S3 prefix (folder). |
| **Request** | A single submission containing a command (text) and optional file attachments. |
| **Request ID** | Unique identifier in format `{unix_timestamp}_{8-char-hex}` (e.g. `1740000000_a1b2c3d4`). |
| **REQUESTS.md** | Markdown file in each project prefix that logs all requests chronologically. |
| **Data bucket** | S3 bucket `pa-kanyuka-info-data` — stores all project files. |
| **rclone mount** | FUSE-based filesystem mount that presents S3 as a local folder with VFS caching. |

### 1.4 Change Log

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-02-21 | Initial SRS with EFS-based storage |
| 2.0 | 2026-02-21 | Replaced EFS with S3 + KMS. Added multi-device access via rclone. Removed VPC/EFS networking. Added client access section. |

---

## 2. Overall Description

### 2.1 User Profile

The system is designed for a single user or a small group of trusted users (controlled via email allowlist). Users must have a Google account on the allowlist to access the system.

### 2.2 Access Points

Files can be added and read from three sources:

| Access Point | Write | Read | Method |
|-------------|-------|------|--------|
| Ubuntu laptop | Yes | Yes (NVMe-speed cached) | rclone mount with VFS cache |
| MacBook Air | Yes | Yes (NVMe-speed cached) | rclone mount with VFS cache |
| Web portal (pa.kanyuka.info) | Yes (upload) | No | Lambda → S3 boto3 |

### 2.3 User Workflows

**Web portal workflow:**
1. Navigate to `https://pa.kanyuka.info`
2. Authenticate via Google Sign-In
3. Select an existing project or create a new one
4. Type a command, optionally attach files
5. Submit — Lambda writes files to S3
6. Files appear on mounted laptops within 30 seconds

**Laptop workflow:**
1. Open mounted folder (`~/PA-Projects/projects/`)
2. Browse project folders like normal directories
3. Copy/create/edit files — writes go to local cache, upload to S3 in background
4. Files uploaded from other devices appear on next directory refresh (30s)

### 2.4 Operating Environment

| Parameter | Value |
|-----------|-------|
| Cloud provider | AWS |
| Region | `eu-central-1` (Frankfurt) |
| Domain | `pa.kanyuka.info` (Route 53 zone: `kanyuka.info`) |
| Runtime | Python 3.12 on AWS Lambda |
| Storage | AWS S3 with KMS encryption, versioning enabled |
| Frontend hosting | S3 + CloudFront |
| Client access | rclone mount (Linux, macOS) |

---

## 3. Functional Requirements

### 3.1 Authentication

| ID | Requirement | Status |
|----|-------------|--------|
| FR-AUTH-01 | System shall authenticate users via Google Sign-In (OAuth 2.0 ID tokens) | Implemented |
| FR-AUTH-02 | System shall verify the Google ID token JWT: audience, expiry, and issuer claims | Implemented |
| FR-AUTH-03 | System shall restrict access to emails listed in the `ALLOWED_EMAILS` configuration | Implemented |
| FR-AUTH-04 | Unauthenticated requests to protected endpoints shall return HTTP 401 | Implemented |
| FR-AUTH-05 | Authenticated users not on the allowlist shall receive HTTP 403 | Implemented |
| FR-AUTH-06 | The frontend shall display user name and avatar after sign-in | Implemented |
| FR-AUTH-07 | The frontend shall provide a Sign Out button that clears the session | Implemented |

### 3.2 Project Management

| ID | Requirement | Status |
|----|-------------|--------|
| FR-PROJ-01 | System shall list existing projects by reading top-level prefixes from S3 | Implemented |
| FR-PROJ-02 | Frontend shall display projects in a dropdown (combobox) sorted alphabetically | Implemented |
| FR-PROJ-03 | Frontend shall offer a "+ New Project" option that reveals a text input | Implemented |
| FR-PROJ-04 | New project names shall be validated: 1–100 characters, no forbidden characters (`/\<>:"\|?*`) | Implemented |
| FR-PROJ-05 | Project prefixes shall be created automatically on first request | Implemented |

### 3.3 Request Submission

| ID | Requirement | Status |
|----|-------------|--------|
| FR-REQ-01 | User shall enter a command in a multi-line text area (required field) | Implemented |
| FR-REQ-02 | User shall optionally attach one or more files | Implemented |
| FR-REQ-03 | Files can be added via file picker or drag-and-drop | Implemented |
| FR-REQ-04 | Frontend shall display selected files with name, size, and a remove button | Implemented |
| FR-REQ-05 | Submission shall send `multipart/form-data` POST to `/api/request` | Implemented |
| FR-REQ-06 | System shall generate a unique request ID: `{unix_timestamp}_{uuid_hex8}` | Implemented |
| FR-REQ-07 | System shall store files under `projects/{project}/{request_id}/` in S3 | Implemented |
| FR-REQ-08 | System shall write `request.json` with metadata (id, project, command, user, timestamp, files) | Implemented |
| FR-REQ-09 | System shall write `command.txt` with the raw command text | Implemented |
| FR-REQ-10 | System shall save uploaded files with sanitized filenames | Implemented |
| FR-REQ-11 | System shall update `REQUESTS.md` in the project prefix | Implemented |
| FR-REQ-12 | On success, response shall include request ID, project name, and saved file list | Implemented |
| FR-REQ-13 | Frontend shall clear the form and refresh the project list after successful submission | Implemented |

### 3.4 Request History

| ID | Requirement | Status |
|----|-------------|--------|
| FR-HIST-01 | Each project prefix shall contain a `REQUESTS.md` file | Implemented |
| FR-HIST-02 | `REQUESTS.md` shall be created with a project header on first request | Implemented |
| FR-HIST-03 | Each entry shall include: timestamp, request ID, user email, command (in code block), file list | Implemented |
| FR-HIST-04 | Entries shall be appended chronologically (read-modify-write on S3) | Implemented |

### 3.5 Multi-Device File Access

| ID | Requirement | Status |
|----|-------------|--------|
| FR-MULTI-01 | Files shall be accessible from Ubuntu laptop via rclone mount | Implemented |
| FR-MULTI-02 | Files shall be accessible from MacBook Air via rclone mount | Implemented |
| FR-MULTI-03 | Files written on any device shall be visible on other devices within 60 seconds | Implemented |
| FR-MULTI-04 | Local reads after first access shall be NVMe-speed (VFS cache) | Implemented |
| FR-MULTI-05 | Local writes shall be cached and uploaded to S3 in background | Implemented |
| FR-MULTI-06 | Setup scripts shall be provided for both Ubuntu and macOS | Implemented |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement | Value |
|----|-------------|-------|
| NFR-PERF-01 | Lambda timeout | 60 seconds |
| NFR-PERF-02 | Lambda memory | 256 MB |
| NFR-PERF-03 | API Gateway payload limit | 10 MB (AWS default for HTTP API) |
| NFR-PERF-04 | CloudFront default cache TTL | 3600 seconds (1 hour) |
| NFR-PERF-05 | rclone directory cache refresh | 30 seconds |
| NFR-PERF-06 | rclone write-back delay | 5 seconds |
| NFR-PERF-07 | rclone local cache max size | 10 GB |

### 4.2 Availability

| ID | Requirement | Value |
|----|-------------|-------|
| NFR-AVAIL-01 | S3 durability | 99.999999999% (11 nines) |
| NFR-AVAIL-02 | S3 availability | 99.99% |
| NFR-AVAIL-03 | CloudFront | Global edge network |

### 4.3 Security

| ID | Requirement | Value |
|----|-------------|-------|
| NFR-SEC-01 | HTTPS enforced | CloudFront redirects HTTP → HTTPS |
| NFR-SEC-02 | TLS minimum version | TLS 1.2 |
| NFR-SEC-03 | S3 encryption | SSE-KMS (AES-256, customer-managed key) |
| NFR-SEC-04 | CORS | Restricted to `https://pa.kanyuka.info` |
| NFR-SEC-05 | S3 public access | Blocked (all public access settings denied) |
| NFR-SEC-06 | IAM least privilege | Lambda role has only logs and S3 data bucket access |
| NFR-SEC-07 | S3 versioning | Enabled (recovery from accidental overwrites) |
| NFR-SEC-08 | rclone transport | HTTPS to S3 API |
| NFR-SEC-09 | Client authentication | AWS IAM credentials (access key) for rclone |

### 4.4 Maintainability

| ID | Requirement | Value |
|----|-------------|-------|
| NFR-MAINT-01 | Lambda dependencies | boto3 only (included in Lambda runtime) |
| NFR-MAINT-02 | Infrastructure as code | All resources in Terraform |
| NFR-MAINT-03 | Deployment scripts | Full, frontend-only, Lambda-only, rclone setup |

---

## 5. User Interface Requirements

### 5.1 Pages

The application is a single-page application with two states:

**Unauthenticated state:**
- Centered login card with title "Sign in to continue"
- Google Sign-In button (standard size, outline theme)

**Authenticated state:**
- Header with app title, user avatar, name, and Sign Out button
- Request form with:
  - Project dropdown (existing projects + "+ New Project" option)
  - New project name input (shown conditionally)
  - Command textarea (4 rows, required)
  - File upload area (click or drag-and-drop, multiple files)
  - File list with name, size, and remove button per file
  - Submit button with loading spinner
- Result section (shown after submission) with JSON response or error

### 5.2 Visual Design

| Property | Value |
|----------|-------|
| Theme | Dark |
| Background | `#0f172a` |
| Surface | `#1e293b` |
| Primary color | `#3b82f6` (blue) |
| Text | `#e2e8f0` |
| Muted text | `#94a3b8` |
| Error | `#ef4444` (red) |
| Success | `#22c55e` (green) |
| Border radius | 8px |
| Max width | 720px, centered |
| Font | System font stack (-apple-system, BlinkMacSystemFont, Segoe UI, Roboto) |
| Responsive | Mobile-friendly (stacked layout below 600px) |

---

## 6. API Specification

**Base URL:** `https://api.pa.kanyuka.info`

### 6.1 GET /api/health

No authentication required.

**Response 200:**
```json
{ "status": "ok" }
```

### 6.2 GET /api/projects

**Headers:** `Authorization: Bearer <google_id_token>`

**Response 200:**
```json
{ "projects": ["project-alpha", "project-beta"] }
```

### 6.3 POST /api/request

**Headers:** `Authorization: Bearer <google_id_token>`
**Content-Type:** `multipart/form-data`

**Form fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project` | string | Yes* | Existing project name |
| `new_project` | string | Yes* | New project name (takes precedence over `project`) |
| `command` | string | Yes | Command / request text |
| `files` | file(s) | No | One or more file attachments |

*One of `project` or `new_project` must be non-empty.

**Response 200:**
```json
{
  "message": "Request created",
  "request_id": "1740000000_a1b2c3d4",
  "project": "project-alpha",
  "files_saved": ["report.pdf", "data.csv"]
}
```

### 6.4 CORS

| Header | Value |
|--------|-------|
| `Access-Control-Allow-Origin` | `https://pa.kanyuka.info` |
| `Access-Control-Allow-Methods` | `GET, POST, OPTIONS` |
| `Access-Control-Allow-Headers` | `Content-Type, Authorization` |
| `Access-Control-Max-Age` | `86400` |

---

## 7. Data Model

### 7.1 S3 Object Structure

```
s3://pa-kanyuka-info-data/
└── projects/
    └── {project_name}/
        ├── REQUESTS.md
        └── {request_id}/
            ├── request.json
            ├── command.txt
            └── {uploaded_files...}
```

### 7.2 request.json Schema

```json
{
  "request_id": "1740000000_a1b2c3d4",
  "project": "project-alpha",
  "command": "analyze these documents",
  "user": "user@gmail.com",
  "timestamp": "2026-02-21T14:30:00Z",
  "files": ["report.pdf", "data.csv"]
}
```

### 7.3 Input Validation Rules

| Field | Rule |
|-------|------|
| Project name | 1–100 characters; forbidden: `/\<>:"\|?*\0`; cannot be `.` or `..` |
| Uploaded filename | Sanitized to alphanumeric, `.`, `-`, `_`, space; path traversal removed via `os.path.basename` |
| Command | Non-empty string (required) |

---

## 8. Architecture

### 8.1 System Diagram

```
 Ubuntu Laptop             MacBook Air             Web Portal
 ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐
 │ /mnt/pa/     │    │ /Volumes/pa/ │    │ pa.kanyuka.info      │
 │ projects/    │    │ projects/    │    │  → API Gateway       │
 │ (rclone      │    │ (rclone      │    │  → Lambda            │
 │  mount)      │    │  mount)      │    │                      │
 └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘
        │ rclone             │ rclone                │ boto3
        └────────┬───────────┴───────────────────────┘
                 │
          ┌──────▼──────────────────┐
          │  S3: pa-kanyuka-info-data│
          │  SSE-KMS encrypted       │
          │  Versioning enabled      │
          │  Public access blocked   │
          └─────────────────────────┘

 pa.kanyuka.info          api.pa.kanyuka.info
        │                         │
 ┌──────▼──────┐          ┌──────▼──────────┐
 │ CloudFront  │          │  API Gateway    │
 │ (CDN+HTTPS) │          │  (HTTP API)     │
 └──────┬──────┘          └──────┬──────────┘
        │                        │
 ┌──────▼──────┐          ┌──────▼──────────┐
 │ S3 Frontend │          │  Lambda         │
 │ (static)    │          │  Python 3.12    │
 └─────────────┘          └─────────────────┘
```

### 8.2 Component Details

#### Frontend

| Property | Value |
|----------|-------|
| Type | Static SPA (HTML + CSS + JS) |
| Hosting | S3 bucket `pa-kanyuka-info-frontend` |
| CDN | CloudFront with custom domain `pa.kanyuka.info` |
| TLS | ACM certificate (us-east-1) for `pa.kanyuka.info` + `*.pa.kanyuka.info` |
| Auth library | Google Identity Services |
| Dependencies | None (vanilla JS) |

#### API Gateway

| Property | Value |
|----------|-------|
| Type | HTTP API (APIGatewayV2) |
| Custom domain | `api.pa.kanyuka.info` |
| TLS | ACM certificate (eu-central-1) |
| Routes | `GET /api/health`, `GET /api/projects`, `POST /api/request`, `OPTIONS /{proxy+}` |

#### Lambda Function

| Property | Value |
|----------|-------|
| Function name | `personal-assistant-handler` |
| Runtime | Python 3.12 |
| Handler | `lambda_function.lambda_handler` |
| Memory | 256 MB |
| Timeout | 60 seconds |
| VPC | Not required (S3 accessed via public endpoint) |
| Dependencies | boto3 (included in Lambda runtime) |
| Package | Single `lambda_function.py` in `function.zip` |

**Environment variables:**

| Variable | Value |
|----------|-------|
| `S3_DATA_BUCKET` | `pa-kanyuka-info-data` |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `ALLOWED_EMAILS` | Comma-separated email allowlist |
| `ALLOWED_ORIGIN` | `https://pa.kanyuka.info` |

#### S3 Data Bucket

| Property | Value |
|----------|-------|
| Bucket name | `pa-kanyuka-info-data` |
| Encryption | SSE-KMS (customer-managed key, AES-256) |
| Versioning | Enabled |
| Public access | All blocked |
| Access | Lambda IAM role + rclone IAM user |

### 8.3 Request Processing Flow

```
POST /api/request
       │
       ▼
  Verify Google token ── fail ──► 401
       │
       ▼
  Check email allowlist ── fail ──► 403
       │
       ▼
  Parse multipart body
       │
       ▼
  Validate project + command ── fail ──► 400
       │
       ▼
  Generate request ID: {timestamp}_{hex8}
       │
       ▼
  Upload to S3:
  ├─ projects/{project}/{request_id}/request.json
  ├─ projects/{project}/{request_id}/command.txt
  └─ projects/{project}/{request_id}/{files...}
       │
       ▼
  Update projects/{project}/REQUESTS.md
  (download existing → append → re-upload)
       │
       ▼
  Return 200 + { request_id, project, files_saved }
```

---

## 9. Infrastructure

### 9.1 AWS Resources

| Resource | Terraform Name | Purpose |
|----------|---------------|---------|
| S3 Data Bucket | `aws_s3_bucket.data` | Project file storage |
| KMS Key | `aws_kms_key.data` | S3 encryption key |
| S3 Frontend Bucket | `aws_s3_bucket.frontend` | Frontend hosting |
| Lambda Function | `aws_lambda_function.assistant` | Request processing |
| IAM Role (Lambda) | `aws_iam_role.lambda_role` | Lambda execution |
| IAM User (rclone) | `aws_iam_user.rclone` | Client device S3 access |
| API Gateway HTTP API | `aws_apigatewayv2_api.api` | HTTP routing |
| CloudFront Distribution | `aws_cloudfront_distribution.frontend` | CDN + HTTPS |
| ACM Certificate (us-east-1) | `aws_acm_certificate.cert` | TLS for CloudFront |
| ACM Certificate (eu-central-1) | `aws_acm_certificate.api_cert` | TLS for API Gateway |
| Route 53 Records | `aws_route53_record.frontend`, `.api` | DNS |

**Removed from v1.0:** VPC, subnets, security groups, EFS, EFS mount targets, EFS access point, VPC-related IAM policies.

### 9.2 Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `eu-central-1` | AWS region |
| `project_name` | `personal-assistant` | Resource naming prefix |
| `s3_bucket_name` | `pa-kanyuka-info-frontend` | Frontend S3 bucket |
| `s3_data_bucket_name` | `pa-kanyuka-info-data` | Data S3 bucket |
| `subdomain` | `pa.kanyuka.info` | Frontend domain |
| `domain_zone` | `kanyuka.info` | Route 53 hosted zone |
| `google_client_id` | (required, sensitive) | Google OAuth Client ID |
| `allowed_emails` | `""` | Comma-separated email allowlist |

---

## 10. Security

### 10.1 Encryption

- **At rest:** S3 SSE-KMS with customer-managed key (AES-256). AWS manages key material, key rotation available.
- **In transit:** All S3 access over HTTPS (TLS 1.2+). CloudFront enforces HTTPS redirect. API Gateway uses TLS 1.2.

### 10.2 Access Control

- **Web portal:** Google OAuth 2.0 ID tokens + email allowlist
- **Lambda → S3:** IAM role with scoped permissions (only the data bucket)
- **rclone → S3:** Dedicated IAM user with access key, scoped to data bucket only
- **S3 bucket:** All public access blocked, bucket policy restricts to Lambda role + rclone user

### 10.3 Data Protection

- **S3 versioning:** Enabled — protects against accidental overwrite/delete, all versions recoverable
- **Filename sanitization:** Path traversal prevention via `os.path.basename` + character filtering
- **No public exposure:** Data bucket has no public access; frontend bucket is separate

### 10.4 Credential Management

- **Lambda:** IAM role (no credentials in code)
- **rclone:** IAM access key stored in `~/.config/rclone/rclone.conf` (file permissions 600)
- **Terraform:** `*.tfvars` and state files in `.gitignore`

---

## 11. Client Access (rclone)

### 11.1 Overview

Client devices mount the S3 data bucket as a local folder using rclone with full VFS caching.

### 11.2 Mount Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `--vfs-cache-mode` | `full` | Cache reads and writes locally |
| `--vfs-cache-max-size` | `10G` | Max local cache disk usage |
| `--vfs-write-back` | `5s` | Write to cache first, upload after 5s |
| `--dir-cache-time` | `30s` | Refresh directory listings every 30s |
| `--vfs-read-ahead` | `128M` | Pre-read buffer for large files |

### 11.3 Mount Points

| Device | Mount point | Cache location |
|--------|-------------|---------------|
| Ubuntu laptop | `~/PA-Projects` | `~/.cache/rclone/` |
| MacBook Air | `~/PA-Projects` | `~/Library/Caches/rclone/` |

### 11.4 Performance Characteristics

| Operation | Speed |
|-----------|-------|
| Write file | Instant (local NVMe cache, uploads in background) |
| Read file (first time) | Network download speed |
| Read file (cached) | Local NVMe speed |
| See new files from another device | Up to 30 seconds (dir-cache-time) |
| Directory listing | Fast (cached, refreshed every 30s) |

---

## 12. Deployment

### 12.1 Prerequisites

- AWS CLI configured for `eu-central-1`
- Terraform >= 1.0
- Google Cloud Console project with OAuth 2.0 Client ID
- rclone installed on client devices

### 12.2 Scripts

| Script | Description |
|--------|-------------|
| `scripts/deploy.sh` | Full deploy: Lambda, Terraform, frontend |
| `scripts/update-frontend.sh` | Frontend-only deploy |
| `scripts/update-lambda.sh` | Lambda-only deploy |
| `scripts/setup-rclone-linux.sh` | Configure rclone + systemd mount on Ubuntu |
| `scripts/setup-rclone-macos.sh` | Configure rclone + LaunchAgent mount on macOS |

---

## 13. Constraints and Assumptions

### 13.1 Constraints

- API Gateway payload limit: 10 MB per request
- Lambda timeout: 60 seconds
- S3 objects are immutable (no append — `REQUESTS.md` is downloaded, modified, re-uploaded)
- No file locking — simultaneous edits to the same file result in last-write-wins
- rclone dir-cache-time introduces up to 30s delay for cross-device visibility
- JWT verification checks claims only (no cryptographic signature validation)

### 13.2 Assumptions

- Single user or small trusted group
- `kanyuka.info` is a Route 53 hosted zone in the AWS account
- rclone is installed on client devices
- Simultaneous edits to the same file from different devices are rare
