import json
import os
import uuid
import base64
import time

import boto3

S3_DATA_BUCKET = os.environ.get("S3_DATA_BUCKET", "pa-kanyuka-info-data")
PROJECTS_PREFIX = "projects/"
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
ALLOWED_EMAILS = os.environ.get("ALLOWED_EMAILS", "").split(",")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("ALLOWED_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
}

s3 = boto3.client("s3")


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("rawPath", "/")

    if method == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    if path == "/api/health":
        return _response(200, {"status": "ok"})

    token = _extract_token(event)
    user_email = _verify_google_token(token)
    if not user_email:
        return _response(401, {"error": "Unauthorized"})

    if ALLOWED_EMAILS and ALLOWED_EMAILS != [""] and user_email not in ALLOWED_EMAILS:
        return _response(403, {"error": "Forbidden"})

    if path == "/api/projects" and method == "GET":
        return _list_projects()
    elif path == "/api/request" and method == "POST":
        return _create_request(event, user_email)
    else:
        return _response(404, {"error": "Not found"})


def _list_projects():
    projects = set()
    paginator = s3.get_paginator("list_objects_v2")
    pages = paginator.paginate(
        Bucket=S3_DATA_BUCKET,
        Prefix=PROJECTS_PREFIX,
        Delimiter="/",
    )
    for page in pages:
        for prefix in page.get("CommonPrefixes", []):
            name = prefix["Prefix"][len(PROJECTS_PREFIX):].rstrip("/")
            if name:
                projects.add(name)

    return _response(200, {"projects": sorted(projects)})


def _create_request(event, user_email):
    try:
        raw_body = event.get("body", "")
        if event.get("isBase64Encoded"):
            body_bytes = base64.b64decode(raw_body)
        else:
            body_bytes = raw_body.encode("utf-8") if isinstance(raw_body, str) else raw_body

        content_type = _get_header(event, "content-type")

        if content_type and "multipart/form-data" in content_type:
            fields, files = _parse_multipart(body_bytes, content_type)
            project_name = fields.get("project", "").strip()
            new_project = fields.get("new_project", "").strip()
            action = fields.get("action", "notes").strip()
            notes = fields.get("notes", "").strip()
            instruction = fields.get("instruction", "").strip()
        else:
            data = json.loads(body_bytes if isinstance(body_bytes, str) else body_bytes.decode("utf-8"))
            project_name = data.get("project", "").strip()
            new_project = data.get("new_project", "").strip()
            action = data.get("action", "notes").strip()
            notes = data.get("notes", "").strip()
            instruction = data.get("instruction", "").strip()
            files = {}

        if new_project:
            project_name = new_project

        if not project_name:
            return _response(400, {"error": "Project name is required"})

        if action not in ("notes", "files", "audio"):
            return _response(400, {"error": "Invalid action. Must be 'notes', 'files', or 'audio'"})

        _sanitize_name(project_name)
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        if action == "notes":
            if not notes:
                return _response(400, {"error": "Notes are required"})

            _update_notes_md(project_name, user_email, timestamp, notes, None)

            return _response(200, {
                "message": "Notes added",
                "project": project_name,
                "timestamp": timestamp,
            })

        if action == "audio":
            if not files:
                return _response(400, {"error": "Audio recording is required"})

            request_id = f"{int(time.time())}_{uuid.uuid4().hex[:8]}"
            prefix = f"{PROJECTS_PREFIX}{project_name}/{request_id}/"
            audio_filenames = []

            for filename, file_data in files.items():
                safe_name = _sanitize_filename(filename)
                s3.put_object(
                    Bucket=S3_DATA_BUCKET,
                    Key=f"{prefix}{safe_name}",
                    Body=file_data,
                )
                audio_filenames.append(safe_name)

            request_meta = {
                "request_id": request_id,
                "project": project_name,
                "command": "Audio note",
                "notes": notes,
                "user": user_email,
                "timestamp": timestamp,
                "files": audio_filenames,
            }

            s3.put_object(
                Bucket=S3_DATA_BUCKET,
                Key=f"{prefix}request.json",
                Body=json.dumps(request_meta, indent=2).encode("utf-8"),
                ContentType="application/json",
            )

            _update_requests_md(project_name, request_meta)

            audio_note = f"Audio note recorded ({', '.join(audio_filenames)})."
            audio_note += "\nThis is an audio note — please transcribe and add the content here."
            if notes:
                audio_note = notes + "\n\n" + audio_note
            _update_notes_md(project_name, user_email, timestamp, audio_note, None,
                             file_list=audio_filenames, request_id=request_id)

            return _response(200, {
                "message": "Audio note saved",
                "request_id": request_id,
                "project": project_name,
                "files_saved": audio_filenames,
            })

        # action == "files"
        if not files:
            return _response(400, {"error": "At least one file is required"})

        command = instruction or notes or "File upload"
        request_id = f"{int(time.time())}_{uuid.uuid4().hex[:8]}"
        prefix = f"{PROJECTS_PREFIX}{project_name}/{request_id}/"

        request_meta = {
            "request_id": request_id,
            "project": project_name,
            "command": command,
            "notes": notes,
            "instruction": instruction,
            "user": user_email,
            "timestamp": timestamp,
            "files": list(files.keys()),
        }

        s3.put_object(
            Bucket=S3_DATA_BUCKET,
            Key=f"{prefix}request.json",
            Body=json.dumps(request_meta, indent=2).encode("utf-8"),
            ContentType="application/json",
        )

        s3.put_object(
            Bucket=S3_DATA_BUCKET,
            Key=f"{prefix}command.txt",
            Body=command.encode("utf-8"),
            ContentType="text/plain",
        )

        for filename, file_data in files.items():
            safe_name = _sanitize_filename(filename)
            s3.put_object(
                Bucket=S3_DATA_BUCKET,
                Key=f"{prefix}{safe_name}",
                Body=file_data,
            )

        _update_requests_md(project_name, request_meta)

        if notes or instruction:
            _update_notes_md(project_name, user_email, timestamp, notes, instruction,
                             file_list=list(files.keys()), request_id=request_id)

        return _response(200, {
            "message": "Request created",
            "request_id": request_id,
            "project": project_name,
            "files_saved": list(files.keys()),
        })
    except ValueError as e:
        return _response(400, {"error": str(e)})
    except Exception as e:
        return _response(500, {"error": f"Internal error: {str(e)}"})


def _update_notes_md(project_name, user_email, timestamp, notes, instruction,
                     file_list=None, request_id=None):
    """Append an entry to the project's NOTES.md."""
    key = f"{PROJECTS_PREFIX}{project_name}/NOTES.md"

    existing = ""
    try:
        resp = s3.get_object(Bucket=S3_DATA_BUCKET, Key=key)
        existing = resp["Body"].read().decode("utf-8")
    except s3.exceptions.NoSuchKey:
        existing = f"# {project_name} — Notes\n\n"

    entry = f"## [{timestamp}] {user_email}\n\n"

    if notes:
        entry += f"{notes}\n\n"

    if instruction:
        entry += f"**Instruction:** {instruction}\n\n"

    if file_list:
        entry += f"**Files ({request_id}):** {', '.join(file_list)}\n\n"

    entry += "---\n\n"

    s3.put_object(
        Bucket=S3_DATA_BUCKET,
        Key=key,
        Body=(existing + entry).encode("utf-8"),
        ContentType="text/markdown",
    )


def _update_requests_md(project_name, meta):
    """Download existing REQUESTS.md, append new entry, re-upload."""
    key = f"{PROJECTS_PREFIX}{project_name}/REQUESTS.md"

    existing = ""
    try:
        resp = s3.get_object(Bucket=S3_DATA_BUCKET, Key=key)
        existing = resp["Body"].read().decode("utf-8")
    except s3.exceptions.NoSuchKey:
        existing = f"# {project_name} — Request History\n\n"

    timestamp = meta["timestamp"]
    request_id = meta["request_id"]
    user = meta["user"]
    command = meta["command"]
    files_list = meta.get("files", [])

    entry = f"## [{timestamp}] {request_id}\n\n"
    entry += f"- **User:** {user}\n"
    entry += f"- **Command:**\n\n"
    entry += f"```\n{command}\n```\n\n"
    if files_list:
        entry += f"- **Files:** {', '.join(files_list)}\n"
    else:
        entry += f"- **Files:** none\n"
    entry += f"\n---\n\n"

    s3.put_object(
        Bucket=S3_DATA_BUCKET,
        Key=key,
        Body=(existing + entry).encode("utf-8"),
        ContentType="text/markdown",
    )


def _sanitize_name(name):
    if not name or len(name) > 100:
        raise ValueError("Name must be 1-100 characters")
    forbidden = set("/\\<>:\"|?*\0")
    if any(c in forbidden for c in name):
        raise ValueError("Name contains forbidden characters")
    if name in (".", ".."):
        raise ValueError("Invalid name")
    return name


def _sanitize_filename(filename):
    name = os.path.basename(filename)
    name = "".join(c if c.isalnum() or c in ".-_ " else "_" for c in name)
    return name or "unnamed_file"


def _parse_multipart(body_bytes, content_type):
    boundary = None
    for part in content_type.split(";"):
        part = part.strip()
        if part.startswith("boundary="):
            boundary = part[len("boundary="):]
            break

    if not boundary:
        raise ValueError("No boundary in multipart content-type")

    fields = {}
    files = {}

    if isinstance(body_bytes, str):
        body_bytes = body_bytes.encode("utf-8")
    delimiter = ("--" + boundary).encode("utf-8")
    parts = body_bytes.split(delimiter)

    for part in parts[1:]:
        if part.startswith(b"--"):
            break

        if b"\r\n\r\n" not in part:
            continue

        header_section, data = part.split(b"\r\n\r\n", 1)
        if data.endswith(b"\r\n"):
            data = data[:-2]

        headers_str = header_section.decode("utf-8", errors="replace")
        disposition = ""
        for line in headers_str.split("\r\n"):
            if line.lower().startswith("content-disposition:"):
                disposition = line

        name = _extract_header_param(disposition, "name")
        filename = _extract_header_param(disposition, "filename")

        if filename:
            files[filename] = data
        elif name:
            fields[name] = data.decode("utf-8", errors="replace")

    return fields, files


def _extract_header_param(header, param):
    search = f'{param}="'
    idx = header.find(search)
    if idx == -1:
        return None
    start = idx + len(search)
    end = header.find('"', start)
    if end == -1:
        return None
    return header[start:end]


def _extract_token(event):
    auth = _get_header(event, "authorization")
    if auth and auth.startswith("Bearer "):
        return auth[7:]
    return None


def _get_header(event, name):
    headers = event.get("headers", {})
    if not headers:
        return None
    for k, v in headers.items():
        if k.lower() == name.lower():
            return v
    return None


def _verify_google_token(token):
    if not token or not GOOGLE_CLIENT_ID:
        return None

    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None

        payload_b64 = parts[1]
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += "=" * padding

        payload = json.loads(base64.urlsafe_b64decode(payload_b64))

        if payload.get("aud") != GOOGLE_CLIENT_ID:
            return None

        exp = payload.get("exp", 0)
        if time.time() > exp:
            return None

        iss = payload.get("iss", "")
        if iss not in ("accounts.google.com", "https://accounts.google.com"):
            return None

        return payload.get("email")
    except Exception:
        return None


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {**CORS_HEADERS, "Content-Type": "application/json"},
        "body": json.dumps(body),
    }
