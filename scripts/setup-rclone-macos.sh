#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
MOUNT_POINT="${HOME}/PA-Projects"
REMOTE_NAME="pa-s3"

echo "=== rclone Setup for macOS ==="

if ! command -v rclone &>/dev/null; then
    echo "Installing rclone via Homebrew..."
    brew install rclone
fi

if ! command -v macfuse &>/dev/null && ! test -d /Library/Filesystems/macfuse.fs; then
    echo ""
    echo "WARNING: macFUSE is required for rclone mount on macOS."
    echo "Install from: https://osxfuse.github.io/"
    echo "  brew install --cask macfuse"
    echo ""
    read -p "Continue anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        exit 1
    fi
fi

echo ""
echo "--- Reading Terraform outputs ---"
cd "$TERRAFORM_DIR"
BUCKET=$(terraform output -raw s3_data_bucket_name)
ACCESS_KEY=$(terraform output -raw rclone_access_key_id)
SECRET_KEY=$(terraform output -raw rclone_secret_access_key)

echo "Bucket: $BUCKET"

RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
mkdir -p "$(dirname "$RCLONE_CONF")"

if grep -q "\\[${REMOTE_NAME}\\]" "$RCLONE_CONF" 2>/dev/null; then
    echo "Remote '${REMOTE_NAME}' already exists in rclone.conf — updating..."
    rclone config delete "$REMOTE_NAME"
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
echo "--- Creating LaunchAgent ---"
PLIST_PATH="${HOME}/Library/LaunchAgents/info.kanyuka.rclone-pa.plist"
mkdir -p "$(dirname "$PLIST_PATH")"
RCLONE_BIN=$(which rclone)

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>info.kanyuka.rclone-pa</string>
    <key>ProgramArguments</key>
    <array>
        <string>${RCLONE_BIN}</string>
        <string>mount</string>
        <string>${REMOTE_NAME}:${BUCKET}</string>
        <string>${MOUNT_POINT}</string>
        <string>--vfs-cache-mode</string>
        <string>full</string>
        <string>--vfs-cache-max-size</string>
        <string>10G</string>
        <string>--vfs-write-back</string>
        <string>5s</string>
        <string>--dir-cache-time</string>
        <string>30s</string>
        <string>--vfs-read-ahead</string>
        <string>128M</string>
        <string>--volname</string>
        <string>Personal Assistant</string>
        <string>--log-level</string>
        <string>INFO</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/rclone-pa.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/rclone-pa.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Mount point:  ${MOUNT_POINT}"
echo "Projects at:  ${MOUNT_POINT}/projects/"
echo "Volume name:  'Personal Assistant' (visible in Finder)"
echo ""
echo "Commands:"
echo "  launchctl list | grep rclone          # check status"
echo "  launchctl unload ${PLIST_PATH}        # stop"
echo "  launchctl load ${PLIST_PATH}          # start"
echo "  ls ${MOUNT_POINT}/projects/           # browse projects"
echo "  cat /tmp/rclone-pa.log                # view logs"
