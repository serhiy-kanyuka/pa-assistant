# Personal Assistant — Requests History

Log of all requests made to the system during development.

---

## Request 1 — 2026-02-21

**Create personal assistant web portal**

Create personal assistant system. Include web portal on Amazon AWS Lambda and Python that has Google authentication, and page where I can select existing project or new project from combobox and edit box where I can type command and I can select files for upload. The Lambda has attached EFS folder, it creates there folder for the project and puts there the files in folder with name request ID and the request text.

---

## Request 2 — 2026-02-21

**Add request history logging**

Please store/add the request, previous and future requests to REQUESTS.md file, or say where you store history/requests.

---

## Request 3 — 2026-02-21

**Cursor interaction storage**

Can cursor store interaction and request to project folder?

---

## Request 4 — 2026-02-21

**Switch domain to pa.kanyuka.info**

I have Route 53 managed domain kanyuka.info, so the Lambda has to run on subdomain pa.kanyuka.info. Please improve Terraforms to manage it.

---

## Request 5 — 2026-02-21

**Create project documentation**

Please create folder docs and create there document that describes the project.

---

## Request 6 — 2026-02-21

**Create SRS + Architecture document**

Please create in docs file SRS + Architecture section and fill it with actual data.

---

## Request 7 — 2026-02-21

**Create requests history file**

Please add in docs file requestshistory.md to store there requests to system.

---

## Request 8 — 2026-02-21

**Research cloud file storage options**

I would like to improve design. I need some network file storage, that I can attach to a folder on my Linux PC, it will download files and it will provide fast read operation like local NVMe drive. I am thinking about NFS/AWS EFS, however please write if there are solutions (Google Drive, iCloud, Nextcloud, etc).

---

## Request 9 — 2026-02-21

**Multi-device secure file sync requirements**

I would like to upload files to cloud file storage and get the files on my desktop PC, and my laptop and on instances to work. And it has to be secure because there will be files with secure sensitive data.

**Decision:** AWS S3 + KMS encryption + rclone mount on laptops. Replaces EFS.

---

## Request 10 — 2026-02-21

**S3 folder structure analysis**

I would like to have folder structure, does it possible with AWS S3?

**Answer:** Yes. S3 uses key prefixes that behave as folders in all tools (AWS Console, CLI, rclone mount, boto3). Via rclone mount, appears as regular directories on Linux/macOS.

---

## Request 11 — 2026-02-21

**Detailed workflow analysis**

How the solution has to work: I have a project with ~100 documents in subfolders. I copy documents to local folder on my Ubuntu laptop, on my MacBook Air laptop, and I also upload images, pictures, voice via the Lambda web service on pa.kanyuka.info to the same folder/project. I would like to have possibility to add files on both laptops and from web service, and to have fast read/edit on both laptops (caching is OK).

---

## Request 12 — 2026-02-21

**Update docs and implement S3 architecture**

Please update docs files regarding latest requests and start to implement.

---

## Request 13 — 2026-02-21

**Mount point: ~/PA-Projects**

Update — I am going to have this projects in folder PA-Projects on the laptop.

---

## Request 14 — 2026-02-21

**Deploy to AWS**

Deploy the full infrastructure to AWS. Created `terraform.tfvars`, packaged Lambda, ran `terraform apply` (37 resources), uploaded frontend to S3, invalidated CloudFront. Result: frontend live at https://pa.kanyuka.info, API at https://api.pa.kanyuka.info.

---

## Request 15 — 2026-02-21

**Configure rclone on the laptop**

Configure rclone on Ubuntu laptop to mount S3 data bucket as local folder at `~/PA-Projects`. Installed rclone v1.73.1, configured `pa-s3` S3 remote, created systemd user service with full VFS caching. Mount active and verified.

---

## Request 16 — 2026-02-21

**Add Notes / Add Files action mode to web portal**

Improve the main page: add an Action combobox to select "Add Notes" or "Add Files". In Notes mode, append notes with timestamp to `NOTES.md`. In Files mode, store files as before plus add notes and instruction to `NOTES.md`. Separate editbox fields for notes and instruction.

---

## Request 17 — 2026-02-21

**Fix mobile UX: toast notifications and project creation in notes mode**

Add Notes should also create projects. On iPhone the button does nothing visible. Need success/failure message at top and form ready for next input. Fixed: toast notifications, removed HTML required (iOS issue), rewrote JS for mobile Safari compat, form resets after submit.

---

## Request 18 — 2026-02-21

**Fix Cyrillic/Unicode text support**

Entering Cyrillic text threw `latin-1 codec can't encode characters` error. Fixed multipart body parsing to use raw bytes and UTF-8 instead of latin-1 encoding.

---

## Request 19 — 2026-02-21

**Add Audio Notes action**

Add action to record audio notes via browser microphone. Show record button, on stop send audio to server, store file, add note to NOTES.md saying "audio notes, please transcribe and add here".

---
