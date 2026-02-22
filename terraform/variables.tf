variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "personal-assistant"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  type        = string
  default     = "pa-kanyuka-info-frontend"
}

variable "s3_data_bucket_name" {
  description = "Name of the S3 bucket for project data"
  type        = string
  default     = "pa-kanyuka-info-data"
}

variable "subdomain" {
  description = "Subdomain for the application (e.g. pa.kanyuka.info)"
  type        = string
  default     = "pa.kanyuka.info"
}

variable "domain_zone" {
  description = "Route53 managed domain zone"
  type        = string
  default     = "kanyuka.info"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
  default     = "../backend/function.zip"
}

variable "google_client_id" {
  description = "Google OAuth 2.0 Client ID"
  type        = string
  sensitive   = true
}

variable "allowed_emails" {
  description = "Comma-separated list of allowed email addresses"
  type        = string
  default     = ""
}
