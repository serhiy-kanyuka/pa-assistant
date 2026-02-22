output "frontend_url" {
  value = local.frontend_url
}

output "api_url" {
  value = local.api_url
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "s3_data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.assistant.function_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "kms_key_arn" {
  value = aws_kms_key.data.arn
}

output "rclone_access_key_id" {
  value     = aws_iam_access_key.rclone.id
  sensitive = true
}

output "rclone_secret_access_key" {
  value     = aws_iam_access_key.rclone.secret
  sensitive = true
}
