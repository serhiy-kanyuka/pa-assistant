#!/usr/bin/env bash
set -euo pipefail

ROLE_ARN="arn:aws:iam::872773654986:role/personal-assistant-rclone-role"
MFA_ARN="arn:aws:iam::872773654986:mfa/iPhone-rclone"
DURATION=43200
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

if systemctl --user is-active rclone-pa.service &>/dev/null; then
    echo "Restarting rclone service..."
    systemctl --user restart rclone-pa.service
    sleep 1
    if systemctl --user is-active rclone-pa.service &>/dev/null; then
        echo "rclone service restarted successfully."
    else
        echo "WARNING: rclone service failed to start. Check: journalctl --user -u rclone-pa.service"
    fi
else
    echo "rclone-pa.service is not running. Start it with: systemctl --user start rclone-pa.service"
fi

echo ""
echo "Temporary credentials active until: $EXPIRATION"
echo "Duration: $((DURATION / 3600))h"
echo "Run this script again when credentials expire."
