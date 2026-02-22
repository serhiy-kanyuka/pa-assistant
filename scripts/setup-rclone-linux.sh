#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
MOUNT_POINT="${HOME}/PA-Projects"
REMOTE_NAME="pa-s3"
LOCAL_BIN="${HOME}/.local/bin"

echo "=== rclone Setup for Linux ==="

# Install or upgrade rclone to ~/.local/bin (no sudo required)
RCLONE_BIN="${LOCAL_BIN}/rclone"
if [[ -x "$RCLONE_BIN" ]]; then
    echo "rclone found at ${RCLONE_BIN}: $(${RCLONE_BIN} version | head -1)"
else
    echo "Installing rclone to ${LOCAL_BIN}..."
    mkdir -p "$LOCAL_BIN"
    LATEST=$(curl -sI -L https://github.com/rclone/rclone/releases/latest | grep -i location | sed 's|.*/tag/||;s/\r//')
    DEB_URL="https://github.com/rclone/rclone/releases/download/${LATEST}/rclone-${LATEST}-linux-amd64.deb"
    TMP_DIR=$(mktemp -d)
    curl -L -o "${TMP_DIR}/rclone.deb" "$DEB_URL"
    dpkg-deb -x "${TMP_DIR}/rclone.deb" "${TMP_DIR}/extract"
    cp "${TMP_DIR}/extract/usr/bin/rclone" "$RCLONE_BIN"
    chmod +x "$RCLONE_BIN"
    rm -rf "$TMP_DIR"
    echo "Installed: $(${RCLONE_BIN} version | head -1)"
fi

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "${LOCAL_BIN}"; then
    export PATH="${LOCAL_BIN}:${PATH}"
    if ! grep -q '\.local/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi

# FUSE 2/3 compatibility: create fusermount3 symlink if missing
if ! command -v fusermount3 &>/dev/null && command -v fusermount &>/dev/null; then
    echo "Creating fusermount3 symlink for FUSE 2 compatibility..."
    ln -sf "$(which fusermount)" "${LOCAL_BIN}/fusermount3"
fi

echo ""
echo "--- Reading Terraform outputs ---"
cd "$TERRAFORM_DIR"
BUCKET=$(terraform output -raw s3_data_bucket_name)
ACCESS_KEY=$(terraform output -raw rclone_access_key_id)
SECRET_KEY=$(terraform output -raw rclone_secret_access_key)

echo "Bucket: $BUCKET"
echo "Region: eu-central-1"

RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
mkdir -p "$(dirname "$RCLONE_CONF")"

if grep -q "\\[${REMOTE_NAME}\\]" "$RCLONE_CONF" 2>/dev/null; then
    echo "Remote '${REMOTE_NAME}' already exists in rclone.conf — updating..."
    "${RCLONE_BIN}" config delete "$REMOTE_NAME"
fi

cat >> "$RCLONE_CONF" <<EOF

[${REMOTE_NAME}]
type = s3
provider = AWS
access_key_id = ${ACCESS_KEY}
secret_access_key = ${SECRET_KEY}
region = eu-central-1
server_side_encryption = aws:kms
EOF

chmod 600 "$RCLONE_CONF"
echo "rclone remote '${REMOTE_NAME}' configured"

echo ""
echo "--- Setting up mount point ---"
mkdir -p "$MOUNT_POINT"

echo ""
echo "--- Creating systemd user service ---"
mkdir -p "${HOME}/.config/systemd/user"
cat > "${HOME}/.config/systemd/user/rclone-pa.service" <<EOF
[Unit]
Description=rclone mount for Personal Assistant (S3)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
Environment=PATH=${LOCAL_BIN}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStartPre=/bin/mkdir -p ${MOUNT_POINT}
ExecStart=${RCLONE_BIN} mount ${REMOTE_NAME}:${BUCKET} ${MOUNT_POINT} \
  --vfs-cache-mode full \
  --vfs-cache-max-size 10G \
  --vfs-write-back 5s \
  --dir-cache-time 30s \
  --vfs-read-ahead 128M \
  --log-level INFO
ExecStop=/bin/fusermount -uz ${MOUNT_POINT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable rclone-pa.service
systemctl --user start rclone-pa.service

sleep 2
echo ""
echo "=== Setup Complete ==="
echo ""
systemctl --user status rclone-pa.service --no-pager
echo ""
echo "Mount point:  ${MOUNT_POINT}"
echo "Projects at:  ${MOUNT_POINT}/projects/"
echo ""
echo "Commands:"
echo "  systemctl --user status rclone-pa     # check status"
echo "  systemctl --user restart rclone-pa    # restart"
echo "  systemctl --user stop rclone-pa       # stop"
echo "  ls ${MOUNT_POINT}/projects/           # browse projects"
