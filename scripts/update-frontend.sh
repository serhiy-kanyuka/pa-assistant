#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_DIR/frontend"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

echo "=== Update Frontend ==="

cd "$TERRAFORM_DIR"
API_URL=$(terraform output -raw api_url)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id)

echo "API URL: $API_URL"
echo "S3 Bucket: $S3_BUCKET"

cd "$FRONTEND_DIR"
sed -i "s|const API_ENDPOINT = .*|const API_ENDPOINT = \"${API_URL}\";|" app.js
echo "Updated app.js"

aws s3 sync "$FRONTEND_DIR" "s3://$S3_BUCKET" --delete \
    --exclude "*.bak.*" \
    --region eu-central-1
echo "Uploaded to S3"

aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*" \
    --query "Invalidation.Id" \
    --output text
echo "CloudFront cache invalidated"

echo "=== Done ==="
