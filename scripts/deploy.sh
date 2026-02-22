#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

echo "=== Personal Assistant - Full Deploy ==="

# 1. Package Lambda
echo ""
echo "--- Packaging Lambda function ---"
cd "$BACKEND_DIR"
rm -f function.zip
zip function.zip lambda_function.py
echo "Created function.zip"

# 2. Terraform apply
echo ""
echo "--- Running Terraform ---"
cd "$TERRAFORM_DIR"
terraform init -input=false
terraform plan -out=tfplan
echo ""
read -p "Apply this plan? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 1
fi
terraform apply tfplan
rm -f tfplan

# 3. Get outputs
API_URL=$(terraform output -raw api_url)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id)

# 4. Update frontend API endpoint
echo ""
echo "--- Updating frontend ---"
cd "$FRONTEND_DIR"
sed -i "s|const API_ENDPOINT = .*|const API_ENDPOINT = \"${API_URL}\";|" app.js
echo "Updated API_ENDPOINT to $API_URL"

# 5. Upload frontend to S3
echo ""
echo "--- Uploading frontend to S3 ---"
aws s3 sync "$FRONTEND_DIR" "s3://$S3_BUCKET" --delete \
    --exclude "*.bak.*"

# 6. Invalidate CloudFront cache
echo ""
echo "--- Invalidating CloudFront cache ---"
aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*" \
    --query "Invalidation.Id" \
    --output text

echo ""
echo "=== Deploy complete ==="
echo "Frontend: $(terraform -chdir="$TERRAFORM_DIR" output -raw frontend_url)"
echo "API:      $API_URL"
echo ""
echo "Next: run ./scripts/setup-rclone-linux.sh or ./scripts/setup-rclone-macos.sh"
echo "to mount the data bucket on your devices."
