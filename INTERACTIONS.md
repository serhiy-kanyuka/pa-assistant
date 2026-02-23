# Personal Assistant — Interaction Log

## 2026-02-21 — Initial project scaffolding

**Request:** Create personal assistant system — web portal on AWS Lambda (Python) with Google authentication, project selector combobox, command input, file upload. Lambda has EFS, creates project folders, stores files per request ID.

**Actions:**
- Created full project structure: backend, frontend, terraform, scripts
- Python Lambda with multipart file upload parsing, Google token verification, EFS project/request storage
- Frontend with Google Sign-In, project dropdown, command textarea, drag-and-drop file upload (dark theme)
- Terraform: VPC, EFS, Lambda, API Gateway, S3, CloudFront, ACM certs, Route53 (assistant.kanyuka.info)
- Deploy scripts: full deploy, update-frontend, update-lambda

**Files created:**
- `backend/lambda_function.py` — Lambda handler
- `backend/requirements.txt`
- `frontend/index.html`, `frontend/styles.css`, `frontend/app.js`
- `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`, `terraform/terraform.tfvars.example`
- `scripts/deploy.sh`, `scripts/update-frontend.sh`, `scripts/update-lambda.sh`
- `.gitignore`, `README.md`

---

## 2026-02-21 — Add REQUESTS.md logging per project

**Request:** Store request history in a REQUESTS.md file per project on EFS.

**Actions:**
- Added `_append_to_requests_md()` function to Lambda
- Each request is appended as a markdown entry with timestamp, user, command, and file list
- Updated README to document REQUESTS.md location

**Files changed:**
- `backend/lambda_function.py` — added `_append_to_requests_md()`, called after saving request files
- `README.md` — updated EFS structure diagram to show REQUESTS.md

---

## 2026-02-21 — Enable Cursor interaction logging

**Request:** Store Cursor interactions and requests in the project folder.

**Actions:**
- Created Cursor rule to auto-log interactions to INTERACTIONS.md
- Created INTERACTIONS.md with full history of this session

**Files created:**
- `.cursor/rules/log-interactions.mdc` — always-apply rule for logging
- `INTERACTIONS.md` — interaction log (this file)

---

## 2026-02-21 — Switch domain to pa.kanyuka.info

**Request:** Use `pa.kanyuka.info` subdomain under Route53-managed `kanyuka.info`. Improve Terraform.

**Actions:**
- Changed subdomain from `assistant.kanyuka.info` to `pa.kanyuka.info` across all files
- Added `domain_zone` variable to avoid hardcoded zone name
- Added `locals` block for derived values (`api_domain`, `frontend_url`, `api_url`)
- Refactored subnets and EFS mount targets to use `count` instead of duplicate resources
- CloudFront cert now includes wildcard SAN (`*.pa.kanyuka.info`) for future flexibility
- Added `google_client_id` as sensitive output for deploy script use

**Files changed:**
- `terraform/variables.tf` — new `domain_zone` var, defaults updated to `pa.kanyuka.info`
- `terraform/main.tf` — locals, count-based subnets/EFS mounts, wildcard cert, domain refs
- `terraform/outputs.tf` — use locals, added `google_client_id` output
- `terraform/terraform.tfvars.example` — updated defaults
- `frontend/app.js` — API endpoint to `api.pa.kanyuka.info`
- `README.md` — all domain references updated

---

## 2026-02-21 — Create docs/architecture.md

**Request:** Create a docs folder with a document describing the project.

**Actions:**
- Created `docs/` directory
- Wrote comprehensive architecture document covering all components

**Files created:**
- `docs/architecture.md` — system diagram, components (frontend, API, Lambda, EFS, VPC, DNS), auth flow, infrastructure summary, project structure

---

## 2026-02-21 — Create SRS + Architecture document

**Request:** Create an SRS with Architecture section in docs, filled with actual project data.

**Actions:**
- Created comprehensive SRS document with 12 sections derived from actual codebase

**Files created:**
- `docs/SRS.md` — full SRS covering: introduction, functional requirements (21 items), non-functional requirements, UI specs, API spec, data model, architecture diagrams, infrastructure (all Terraform resources), security, deployment

**Files changed:**
- `docs/architecture.md` — updated project structure tree to include SRS.md

---

## 2026-02-21 — Create requestshistory.md

**Request:** Add a docs file requestshistory.md to store requests to the system.

**Actions:**
- Created `docs/requestshistory.md` with all 7 requests from this session
- Updated project structure in architecture.md

**Files created:**
- `docs/requestshistory.md` — chronological log of all user requests

**Files changed:**
- `docs/architecture.md` — added requestshistory.md to project structure tree

---

## 2026-02-21 — Replace EFS with S3 + KMS, add multi-device rclone access

**Request:** Research storage options, then implement S3-based architecture with multi-device access (Ubuntu laptop, MacBook Air, Lambda) and strong encryption for sensitive data.

**Actions:**
- Replaced EFS with S3 data bucket (KMS encryption, versioning enabled)
- Rewrote Lambda to use boto3 instead of filesystem operations
- Removed VPC/EFS/subnets/security groups from Terraform (major simplification)
- Added S3 data bucket, KMS key, IAM rclone user to Terraform
- Created rclone setup scripts for Ubuntu (systemd service) and macOS (LaunchAgent)
- Updated all docs: SRS v2.0, architecture.md, requestshistory.md (requests 8-12), README

**Files changed:**
- `backend/lambda_function.py` — rewritten: EFS filesystem ops → S3 boto3 (put_object, get_object, list_objects)
- `backend/requirements.txt` — updated comment (boto3 in runtime)
- `terraform/main.tf` — removed VPC/EFS (14 resources), added S3 data bucket, KMS key, IAM rclone user
- `terraform/variables.tf` — removed `vpc_cidr`, added `s3_data_bucket_name`
- `terraform/outputs.tf` — removed `efs_id`, added `s3_data_bucket_name`, `kms_key_arn`, rclone credentials
- `terraform/terraform.tfvars.example` — updated
- `scripts/deploy.sh` — removed EFS references
- `scripts/setup-rclone-linux.sh` — new: rclone config + systemd user service
- `scripts/setup-rclone-macos.sh` — new: rclone config + LaunchAgent plist
- `docs/SRS.md` — v2.0: S3 storage, multi-device requirements, rclone section, removed VPC/EFS
- `docs/architecture.md` — new S3-based diagrams, removed VPC/EFS sections
- `docs/requestshistory.md` — added requests 8-12
- `README.md` — rewritten for S3 architecture + rclone setup instructions

---

## 2026-02-21 — Change mount point to ~/PA-Projects

**Request:** Projects folder should be `~/PA-Projects` on both laptops.

**Actions:**
- Changed mount point from `/mnt/pa` (Linux) and `/Volumes/pa` (macOS) to `~/PA-Projects` on both
- Removed `sudo` from directory creation (home dir, no root needed)

**Files changed:**
- `scripts/setup-rclone-linux.sh` — mount point → `~/PA-Projects`
- `scripts/setup-rclone-macos.sh` — mount point → `~/PA-Projects`
- `docs/SRS.md` — updated mount points and laptop workflow
- `docs/architecture.md` — updated diagram and device table
- `README.md` — updated client access paths
- `docs/requestshistory.md` — added request 13

---

## 2026-02-21 — Deploy to AWS

Deployed the full personal assistant infrastructure to AWS.

**Actions:**
- Created `terraform/terraform.tfvars` with production values (eu-central-1, Google Client ID from anytoua)
- Updated `frontend/index.html` with actual Google Client ID
- Packaged Lambda into `backend/function.zip`
- Ran `terraform init` + `terraform apply` — 37 resources created
- Uploaded frontend files to S3 (`pa-kanyuka-info-frontend`)
- Invalidated CloudFront cache (`E1KUIZURNKD4MK`)
- Verified: API health check OK, frontend returns 200

**Infrastructure created:**
- S3 buckets: `pa-kanyuka-info-frontend`, `pa-kanyuka-info-data` (KMS-encrypted)
- CloudFront distribution `E1KUIZURNKD4MK`
- Lambda `personal-assistant-handler`
- API Gateway with custom domain `api.pa.kanyuka.info`
- ACM certificates for `pa.kanyuka.info` and `api.pa.kanyuka.info`
- KMS key, IAM roles/policies, rclone IAM user
- Route 53 DNS records

**Files changed:**
- `terraform/terraform.tfvars` — created with production config
- `frontend/index.html` — replaced Google Client ID placeholder
- `docs/requestshistory.md` — added request 14

---

## 2026-02-21 21:41 — Configure rclone on Ubuntu laptop

**Request:** Configure rclone on the laptop to mount S3 data bucket as local folder.

**Actions:**
- Upgraded rclone from v1.50.2 to v1.73.1 (installed to `~/.local/bin` without sudo)
- Created `fusermount3` → `fusermount` symlink for FUSE 2/3 compatibility
- Added `pa-s3` S3 remote to rclone.conf using IAM credentials from Terraform outputs
- Created and enabled systemd user service `rclone-pa.service` with VFS full cache
- Verified: mount active at `~/PA-Projects`, files readable (projects/test001 visible)
- Updated `scripts/setup-rclone-linux.sh` to handle no-sudo install, FUSE 2/3 compat, PATH setup

**Files changed:**
- `~/.config/rclone/rclone.conf` — added `[pa-s3]` remote with S3 IAM credentials
- `~/.config/systemd/user/rclone-pa.service` — rclone mount service (VFS cache, auto-restart)
- `~/.local/bin/rclone` — rclone v1.73.1 binary
- `~/.local/bin/fusermount3` — symlink to fusermount for FUSE 2 compat
- `scripts/setup-rclone-linux.sh` — updated: no-sudo install, FUSE 2/3 compat, PATH handling

---

## 2026-02-21 22:00 — Add Notes/Files action mode to web portal

**Request:** Add Action combobox (Add Notes / Add Files), Notes and Instruction editboxes. Notes mode appends to NOTES.md. Files mode stores files as before and also writes notes+instruction to NOTES.md.

**Actions:**
- Added Action dropdown (Add Notes / Add Files) next to Project dropdown
- Added Notes textarea (visible in both modes) and Instruction textarea (visible in Files mode only)
- File upload area only visible in Files mode
- Lambda handles two actions: "notes" (NOTES.md only) and "files" (files + REQUESTS.md + NOTES.md)
- New `_update_notes_md()` function appends timestamped entries to project's NOTES.md
- Deployed Lambda and frontend to AWS
- Fixed deploy scripts to include `--region eu-central-1`

**Files changed:**
- `frontend/index.html` — added Action combobox, Notes/Instruction textareas, conditional Files section
- `frontend/app.js` — action mode switching, new form fields, updated submission logic
- `frontend/styles.css` — added `.form-row` and `.form-group-half` for side-by-side layout
- `backend/lambda_function.py` — new `action`/`notes`/`instruction` fields, `_update_notes_md()`, dual-mode logic
- `scripts/update-lambda.sh` — added `--region eu-central-1`
- `scripts/update-frontend.sh` — added `--region eu-central-1`
- `docs/requestshistory.md` — added request 16

---

## 2026-02-21 22:30 — Fix mobile UX: toast notifications and form reset

**Request:** Add Notes should also create projects. On iPhone, the submit button does nothing visible — need success/failure feedback at top and form ready for next input.

**Actions:**
- Replaced bottom result section with top toast notification (green success / red error)
- Toast auto-hides after 4s (success) or 6s (error), tap to dismiss
- Removed HTML `required` attribute — validation now in JS with toast messages (fixes iOS silent failures)
- Rewrote app.js using `var`/`.then()` instead of `const`/`async-await` for broader mobile Safari compatibility
- After successful submit: form clears, projects reload, page scrolls to top, notes field refocused
- After new project creation: project dropdown resets, new-project input hides
- Deployed Lambda and frontend to AWS

**Files changed:**
- `frontend/index.html` — added toast div, removed result-section, removed `required` from notes textarea
- `frontend/app.js` — rewritten: toast notifications, `.then()` chains, `var` declarations, scroll-to-top, form reset
- `frontend/styles.css` — replaced result-section styles with toast styles (success/error, animation)
- `docs/requestshistory.md` — added request 17

---

## 2026-02-21 22:45 — Fix Cyrillic/Unicode text support

**Request:** Entering Cyrillic text fails with `latin-1 codec can't encode characters` error.

**Actions:**
- Fixed `_create_request`: base64 body now decoded to raw bytes (not UTF-8 string), avoiding re-encoding
- Fixed `_parse_multipart`: accepts bytes directly, uses UTF-8 encoding for boundary delimiter instead of latin-1
- Deployed Lambda

**Files changed:**
- `backend/lambda_function.py` — body handling uses bytes throughout; multipart parser uses UTF-8
- `docs/requestshistory.md` — added request 18

---

## 2026-02-21 23:00 — Narrow mobile layout by 3% each side

**Request:** Decrease width of edit boxes on mobile by 3% from both sides.

**Actions:**
- Added `#app { padding: 16px 3%; }` inside the `@media (max-width: 600px)` block
- Deployed CSS to S3, invalidated CloudFront

**Files changed:**
- `frontend/styles.css` — mobile `#app` padding changed to `3%` horizontal

---

## 2026-02-21 23:15 — Fix iOS Safari horizontal overflow

**Request:** All elements shifted right on iPhone 15.

**Actions:**
- Added `overflow-x: hidden; width: 100%` on `html, body` to prevent horizontal scroll
- Added `overflow: hidden` on `#app` container
- Changed form input `font-size` from `0.9rem` (14.4px) to `16px` — prevents iOS auto-zoom on focus (the main cause)
- Added `max-width: 100%` on form elements, form, and project-row

**Files changed:**
- `frontend/styles.css` — overflow containment, font-size fix, max-width constraints

---

## 2026-02-21 23:30 — Add Audio Notes recording feature

**Request:** Add "Audio Notes" action — record audio in browser, send to server, store file, add transcription placeholder to NOTES.md.

**Actions:**
- Added "Audio Notes" option to Action dropdown
- Audio UI: circular record/stop button with pulsing animation, live timer, audio preview player, discard button
- Uses MediaRecorder API (WebM on Chrome/Firefox, MP4 on Safari/iOS)
- On send: uploads audio blob as timestamped file (audio_note_YYYYMMDD_HHMMSS.m4a/.webm)
- Lambda handles action="audio": stores audio in request folder, updates REQUESTS.md and NOTES.md
- NOTES.md entry: "Audio note recorded (filename). This is an audio note — please transcribe and add the content here."
- Deployed Lambda and frontend

**Files changed:**
- `frontend/index.html` — added "Audio Notes" option, audio-section with recorder UI
- `frontend/app.js` — MediaRecorder logic, toggleRecording, startRecording, stopRecording, discardRecording, audio upload
- `frontend/styles.css` — record button, pulse animation, timer, audio preview, discard button styles
- `backend/lambda_function.py` — action="audio" handler: store audio file, update NOTES.md with transcription placeholder

---

## 2026-02-23 13:30 — Configure rclone on MacBook Air

**Request:** Set up rclone to mount the S3 data bucket on the MacBook Air laptop.

**Actions:**
- Installed rclone v1.73.1 via Homebrew
- Configured `~/.config/rclone/rclone.conf` with `pa-s3` S3 remote (using MFA temporary credentials from `pa-auth.sh`)
- Updated `scripts/setup-rclone-macos.sh` to use `nfsmount` instead of `mount` (no macFUSE dependency)
- Updated `scripts/pa-auth.sh` to detect macOS and start `rclone nfsmount` in background (was Linux-only with systemctl)
- Created `scripts/finish-rclone-macos.sh` helper for standalone credential injection
- Removed LaunchAgent (not suitable for temporary STS credentials; `pa-auth.sh` manages mount lifecycle)
- Verified mount: all 5 projects accessible at `~/PA-Projects/projects/`

**Files changed:**
- `scripts/pa-auth.sh` — added macOS support: nfsmount background process, platform detection, mount verification
- `scripts/setup-rclone-macos.sh` — switched from `mount` to `nfsmount`, removed macFUSE dependency
- `scripts/finish-rclone-macos.sh` — new helper script for one-step credential setup

**Fix (same session):** The `nohup ... & disown` approach for backgrounding rclone on macOS was unreliable — the NFS mount would drop after the parent script exited. Replaced with rclone's native `--daemon --daemon-wait 10s` flags, which properly fork the process and wait for the mount to be ready before the parent exits. Verified mount works: `localhost:/pa-s3 pa-kanyuka-info-data on ~/PA-Projects (nfs)`.

---
