output "oidc_provider_arn" {
  description = "ARN IAM IdP — dùng làm Federated principal cho mọi role tương lai"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "oidc_provider_url" {
  description = "URL IdP (cho audit + interview)"
  value       = aws_iam_openid_connect_provider.github.url
}

output "role_arn" {
  description = "Role ARN — paste vào GHA workflow at .github/workflows/build-push.yml `role-to-assume:`"
  value       = aws_iam_role.gha_ecr_push.arn
}

output "role_name" {
  description = "Role name (cho cleanup/debug)"
  value       = aws_iam_role.gha_ecr_push.name
}

output "policy_arn" {
  description = "Policy ARN ECR push"
  value       = aws_iam_policy.ecr_push.arn
}

output "github_sub_patterns" {
  description = "List sub claim patterns đã chốt (debug khi workflow fail trust)"
  value       = local.github_sub_patterns
}

output "ecr_repo_arns_trusted" {
  description = "List 3 ECR repo ARN role này được push (audit)"
  value       = local.ecr_repo_arns
}
