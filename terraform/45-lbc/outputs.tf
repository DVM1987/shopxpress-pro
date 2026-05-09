output "lbc_release_name" {
  description = "Helm release name (cho audit/troubleshooting kubectl)"
  value       = helm_release.lbc.name
}

output "lbc_release_namespace" {
  description = "Namespace LBC chạy"
  value       = helm_release.lbc.namespace
}

output "lbc_release_version" {
  description = "Chart version đã deploy"
  value       = helm_release.lbc.version
}

output "lbc_release_app_version" {
  description = "App version (image tag) — chart 3.x: chart_version = app_version"
  value       = helm_release.lbc.metadata.app_version
}

output "lbc_release_status" {
  description = "Helm release status (deployed/failed/pending)"
  value       = helm_release.lbc.status
}
