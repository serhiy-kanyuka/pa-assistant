#!/usr/bin/env bash
set -euo pipefail

IAM_USER="personal-assistant-rclone"
MFA_DEVICE_NAME="${IAM_USER}-mfa"

echo "=== Setting up virtual MFA device for ${IAM_USER} ==="

existing=$(aws iam list-mfa-devices --user-name "$IAM_USER" --query 'MFADevices[0].SerialNumber' --output text 2>/dev/null || true)
if [ "$existing" != "None" ] && [ -n "$existing" ]; then
    echo "MFA device already exists: $existing"
    echo "To re-create, first deactivate and delete it:"
    echo "  aws iam deactivate-mfa-device --user-name $IAM_USER --serial-number $existing"
    echo "  aws iam delete-virtual-mfa-device --serial-number $existing"
    exit 1
fi

QR_FILE="/tmp/mfa-qr.png"
SEED_FILE="/tmp/mfa-seed.txt"

echo "Creating virtual MFA device..."
output=$(aws iam create-virtual-mfa-device \
    --virtual-mfa-device-name "$MFA_DEVICE_NAME" \
    --outfile "$QR_FILE" \
    --bootstrap-method QRCodePNG \
    --query 'VirtualMFADevice.SerialNumber' \
    --output text)

MFA_ARN="$output"
echo "MFA device ARN: $MFA_ARN"
echo ""
echo "QR code saved to: $QR_FILE"
echo "Open it and scan with Google Authenticator:"
echo "  xdg-open $QR_FILE"
echo ""

read -rp "Enter the FIRST 6-digit code from Google Authenticator: " CODE1
read -rp "Enter the NEXT 6-digit code (wait for it to change): " CODE2

echo "Activating MFA device..."
aws iam enable-mfa-device \
    --user-name "$IAM_USER" \
    --serial-number "$MFA_ARN" \
    --authentication-code1 "$CODE1" \
    --authentication-code2 "$CODE2"

echo ""
echo "MFA device activated successfully!"
echo "MFA ARN: $MFA_ARN"
echo ""
echo "Cleaning up temporary files..."
rm -f "$QR_FILE" "$SEED_FILE"
echo "Done. You can now use pa-auth.sh to get temporary credentials."
