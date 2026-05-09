output "tfstate_bucket_name" {
  description = "S3 bucket name for storing remote Terraform state of all later sub-components"
  value       = aws_s3_bucket.tfstate.id
}

output "tfstate_bucket_arn" {
  description = "S3 bucket ARN, may be referenced in IAM policies"
  value       = aws_s3_bucket.tfstate.arn
}

output "tfstate_lock_table_name" {
  description = "DynamoDB table name used by the S3 backend for state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "tfstate_lock_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.tfstate_lock.arn
}

output "region" {
  description = "Region where state bucket lives, must match S3 backend block of every later sub-component"
  value       = var.region
}
