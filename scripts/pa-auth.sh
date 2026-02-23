#!/usr/bin/env bash
set -euo pipefail

ROLE_ARN="arn:aws:iam::872773654986:role/personal-assistant-rclone-role"
MFA_ARN="arn:aws:iam::872773654986:mfa/iPhone-rclone"
DURATION=7200
AWS_PROFILE_NAME="pa-rclone"
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
RCLONE_SECTION="pa-s3"

if ! command -v aws &>/dev/null; then
    echo "ERROR: aws CLI not found. Install it first."
    exit 1
fi

if ! aws configure get aws_access_key_id --profile "$AWS_PROFILE_NAME" &>/dev/null; then
    echo "AWS profile '$AWS_PROFILE_NAME' not found."
    echo "Setting it up with the rclone IAM user permanent keys..."
    read -rp "Access Key ID: " ak
    read -rsp "Secret Access Key: " sk
    echo
    aws configure set aws_access_key_id "$ak" --profile "$AWS_PROFILE_NAME"
    aws configure set aws_secret_access_key "$sk" --profile "$AWS_PROFILE_NAME"
    aws configure set region eu-central-1 --profile "$AWS_PROFILE_NAME"
    echo "Profile '$AWS_PROFILE_NAME' saved."
fi

read -rp "Enter 6-digit MFA code from Google Authenticator: " MFA_CODE

if [[ ! "$MFA_CODE" =~ ^[0-9]{6}$ ]]; then
    echo "ERROR: MFA code must be exactly 6 digits."
    exit 1
fi

echo "Assuming role with MFA..."
CREDS=$(aws sts assume-role \
    --profile "$AWS_PROFILE_NAME" \
    --role-arn "$ROLE_ARN" \
    --role-session-name "rclone-$(date +%s)" \
    --serial-number "$MFA_ARN" \
    --token-code "$MFA_CODE" \
    --duration-seconds "$DURATION" \
    --output json)

ACCESS_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
SECRET_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
SESSION_TOKEN=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")
EXPIRATION=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['Expiration'])")

if [ ! -f "$RCLONE_CONF" ]; then
    echo "ERROR: rclone config not found at $RCLONE_CONF"
    exit 1
fi

python3 - "$RCLONE_CONF" "$RCLONE_SECTION" "$ACCESS_KEY" "$SECRET_KEY" "$SESSION_TOKEN" <<'PYEOF'
import configparser, sys

conf_path, section = sys.argv[1], sys.argv[2]
access_key, secret_key, session_token = sys.argv[3], sys.argv[4], sys.argv[5]

config = configparser.ConfigParser()
config.read(conf_path)

if section not in config:
    print(f"ERROR: [{section}] not found in {conf_path}")
    sys.exit(1)

config[section]['access_key_id'] = access_key
config[section]['secret_access_key'] = secret_key
config[section]['session_token'] = session_token

with open(conf_path, 'w') as f:
    config.write(f)

print(f"Updated [{section}] in {conf_path}")
PYEOF

MOUNT_POINT="${HOME}/PA-Projects"
BUCKET="pa-kanyuka-info-data"
mkdir -p "$MOUNT_POINT"

restart_rclone_mount() {
    # Kill any existing rclone mount for PA-Projects
    pkill -f "rclone.*${MOUNT_POINT}" 2>/dev/null || true
    sleep 1
    umount "$MOUNT_POINT" 2>/dev/null || true
    sleep 1

    if [[ "$(uname)" == "Darwin" ]]; then
        RCLONE_BIN="${RCLONE_BIN:-$(command -v rclone)}"
        nohup "$RCLONE_BIN" nfsmount "${RCLONE_SECTION}:${BUCKET}" "$MOUNT_POINT" \
            --vfs-cache-mode full \
            --vfs-cache-max-size 10G \
            --vfs-write-back 5s \
            --dir-cache-time 30s \
            --vfs-read-ahead 128M \
            --log-level INFO \
            --log-file /tmp/rclone-pa.log \
            &>/dev/null &
        disown
    else
        if systemctl --user is-active rclone-pa.service &>/dev/null; then
            systemctl --user restart rclone-pa.service
        else
            systemctl --user start rclone-pa.service
        fi
    fi

    sleep 3
    if ls "${MOUNT_POINT}/projects/" &>/dev/null 2>&1; then
        echo "Mount active at ${MOUNT_POINT}/projects/"
        ls "${MOUNT_POINT}/projects/"
    else
        echo "WARNING: Mount not ready yet. Check: ls ${MOUNT_POINT}/projects/"
        if [[ "$(uname)" == "Darwin" ]]; then
            echo "Logs: cat /tmp/rclone-pa.log"
        else
            echo "Logs: journalctl --user -u rclone-pa.service"
        fi
    fi
}

restart_rclone_mount

echo ""
echo "Temporary credentials active until: $EXPIRATION"
echo "Duration: $((DURATION / 3600))h"
echo "Run this script again when credentials expire."
