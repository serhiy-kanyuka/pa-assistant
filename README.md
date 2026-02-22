# Personal Assistant

Web portal on AWS Lambda (Python) with Google authentication, project management, and file uploads. Files are stored on S3 with KMS encryption and accessible from multiple devices via rclone mount.

## Architecture

```
Ubuntu Laptop ── rclone mount ──┐
                                │
MacBook Air ──── rclone mount ──┼──► S3 Bucket (SSE-KMS, versioned)
                                │
Web Portal ───── Lambda ────────┘

pa.kanyuka.info → CloudFront → S3 (frontend)
api.pa.kanyuka.info → API Gateway → Lambda → S3 (data)
```

- **Frontend**: `pa.kanyuka.info` — static HTML/CSS/JS on S3 + CloudFront
- **API**: `api.pa.kanyuka.info` — HTTP API Gateway → Python Lambda
- **Storage**: S3 bucket `pa-kanyuka-info-data` (KMS encrypted, versioning enabled)
- **Auth**: Google Sign-In (OAuth 2.0 ID tokens)
- **Client access**: rclone mount with VFS cache (NVMe-speed reads)

## S3 Structure

```
s3://pa-kanyuka-info-data/
└── projects/
    ├── my-project/
    │   ├── REQUESTS.md
    │   ├── 1740000000_a1b2c3d4/
    │   │   ├── request.json
    │   │   ├── command.txt
    │   │   └── uploaded_file.py
    │   └── documents/                  (added from laptop via rclone)
    │       └── report.pdf
    └── another-project/
        └── ...
```

## Prerequisites

- AWS CLI configured (`eu-central-1`)
- Terraform >= 1.0
- rclone installed on client devices
- Google Cloud Console project with OAuth 2.0 Client ID
  - Authorized JavaScript origin: `https://pa.kanyuka.info`

## Setup

1. **Create Google OAuth Client ID** at https://console.cloud.google.com/apis/credentials

2. **Configure Terraform:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Google Client ID and allowed emails
   ```

3. **Set Google Client ID in frontend:**
   Edit `frontend/index.html` — replace `GOOGLE_CLIENT_ID_PLACEHOLDER`

4. **Deploy:**
   ```bash
   ./scripts/deploy.sh
   ```

5. **Setup rclone on your devices:**
   ```bash
   # Ubuntu
   ./scripts/setup-rclone-linux.sh

   # macOS
   ./scripts/setup-rclone-macos.sh
   ```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/deploy.sh` | Full deploy: package Lambda, Terraform apply, upload frontend |
| `scripts/update-frontend.sh` | Update frontend files only |
| `scripts/update-lambda.sh` | Update Lambda code only |
| `scripts/setup-rclone-linux.sh` | Configure rclone + systemd mount on Ubuntu |
| `scripts/setup-rclone-macos.sh` | Configure rclone + LaunchAgent mount on macOS |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/projects` | List existing projects |
| POST | `/api/request` | Create request (multipart/form-data with files) |

All endpoints (except health) require `Authorization: Bearer <google_id_token>` header.

## Client Access

After running the rclone setup script, your files are at:
- **Ubuntu**: `~/PA-Projects/projects/`
- **macOS**: `~/PA-Projects/projects/`

Files you add on either laptop or via the web portal appear on all devices within 30 seconds.
