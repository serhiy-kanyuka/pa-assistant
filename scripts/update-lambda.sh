#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

echo "=== Update Lambda ==="

cd "$BACKEND_DIR"
rm -f function.zip
zip function.zip lambda_function.py
echo "Packaged function.zip"

cd "$TERRAFORM_DIR"
FUNCTION_NAME=$(terraform output -raw lambda_function_name)

aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$BACKEND_DIR/function.zip" \
    --region eu-central-1 \
    --query "FunctionName" \
    --output text

echo "Updated Lambda: $FUNCTION_NAME"
echo "=== Done ==="
