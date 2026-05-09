output "repository_urls" {
  description = "Map service → ECR repo URL (registry endpoint, không có tag). Dùng làm image.repository trong Helm values."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "Map service → ARN. Dùng cho IAM policy resource scope (vd GHA push role chỉ Allow 3 repo này)."
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_names" {
  description = "Map service → repo name (không có URI host). Dùng cho aws ecr CLI."
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}

output "registry_id" {
  description = "Account ID = registry ID. Dùng để build URI host: <registry_id>.dkr.ecr.<region>.amazonaws.com"
  value       = data.aws_caller_identity.current.account_id
}

output "registry_scan_type" {
  description = "BASIC hoặc ENHANCED (cho audit + interview proof)"
  value       = aws_ecr_registry_scanning_configuration.this.scan_type
}
