output "eso_release_name" {
  description = "Helm release name (cho audit/troubleshooting kubectl)"
  value       = helm_release.external_secrets.name
}

output "eso_release_namespace" {
  description = "Namespace ESO controller chạy"
  value       = helm_release.external_secrets.namespace
}

output "eso_release_version" {
  description = "Chart version đã deploy"
  value       = helm_release.external_secrets.version
}

output "eso_release_app_version" {
  description = "App version (image tag)"
  value       = helm_release.external_secrets.metadata.app_version
}

output "eso_irsa_role_arn" {
  description = "IAM role ESO controller assume qua IRSA. Sub claim chốt SA external-secrets/external-secrets."
  value       = module.eso_irsa.role_arn
}

output "eso_irsa_role_name" {
  description = "IAM role name (cho cleanup + audit CloudTrail)"
  value       = module.eso_irsa.role_name
}

output "eso_iam_policy_arn" {
  description = "IAM policy ARN — secretsmanager:GetSecretValue + DescribeSecret scope wildcard project/env"
  value       = aws_iam_policy.eso_secretsmanager_read.arn
}

output "demo_secret_arn" {
  description = "ARN secret demo trong SM (có suffix 6 ký tự random AWS auto-add)"
  value       = aws_secretsmanager_secret.demo.arn
}

output "demo_secret_name" {
  description = "Path-style name secret demo"
  value       = aws_secretsmanager_secret.demo.name
}

output "demo_secret_version_id" {
  description = "VersionId của secret_version mới nhất (AWSCURRENT). Khi rotation, version mới được tạo, ESO refresh fetch AWSCURRENT."
  value       = aws_secretsmanager_secret_version.demo.version_id
}

output "app_namespace" {
  description = "K8s namespace nơi ExternalSecret + K8s Secret đẻ ra"
  value       = kubernetes_namespace.app_demo.metadata[0].name
}

output "synced_k8s_secret_name" {
  description = "Tên K8s Secret ESO sync ra. App pod đọc qua envFrom: secretRef.name = <giá trị này>"
  value       = "demo-eso-synced"
}
