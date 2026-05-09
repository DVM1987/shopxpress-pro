output "role_arn" {
  description = "IAM role ARN. Caller annotate vào ServiceAccount: eks.amazonaws.com/role-arn=<arn>. EKS Add-on dùng qua field service_account_role_arn."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name (cho audit + cleanup)"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "IAM role unique ID (audit trail CloudTrail)"
  value       = aws_iam_role.this.unique_id
}
