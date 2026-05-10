output "data_namespace" {
  description = "Namespace chứa StatefulSet PostgreSQL"
  value       = kubernetes_namespace_v1.data.metadata[0].name
}

output "storage_class_name" {
  description = "StorageClass default cho EBS gp3 PVC"
  value       = kubernetes_storage_class_v1.gp3.metadata[0].name
}

output "postgresql_release_names" {
  description = "Tên 2 helm release (audit / kubectl)"
  value = {
    for k, v in helm_release.postgresql : k => v.name
  }
}

output "postgresql_service_dns" {
  description = "DNS nội bộ cluster của 2 PostgreSQL Service (host trong DSN). App pod connect vào DNS này port 5432."
  value = {
    for k, _ in local.databases :
    k => "${k}-db.${var.data_namespace}.svc.cluster.local"
  }
}

output "secrets_manager_arns" {
  description = "ARN 2 secret Secrets Manager — ExternalSecret CRD reference qua `data.remoteRef.key`"
  value = {
    for k, v in aws_secretsmanager_secret.db : k => v.arn
  }
}

output "secrets_manager_names" {
  description = "Tên 2 secret (full path) — ExternalSecret CRD `data.remoteRef.key` field"
  value = {
    for k, v in aws_secretsmanager_secret.db : k => v.name
  }
}
