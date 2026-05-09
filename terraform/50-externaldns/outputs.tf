output "externaldns_release_name" {
  description = "Helm release name (cho audit/troubleshooting kubectl)"
  value       = helm_release.externaldns.name
}

output "externaldns_release_namespace" {
  description = "Namespace ExternalDNS chạy"
  value       = helm_release.externaldns.namespace
}

output "externaldns_release_version" {
  description = "Chart version đã deploy"
  value       = helm_release.externaldns.version
}

output "externaldns_release_app_version" {
  description = "App version (image tag) — chart 1.21.1 → app v0.21.0"
  value       = helm_release.externaldns.metadata.app_version
}

output "externaldns_release_status" {
  description = "Helm release status (deployed/failed/pending)"
  value       = helm_release.externaldns.status
}

output "externaldns_domain_filter" {
  description = "Domain filter đã apply — verify match sub-zone"
  value       = data.terraform_remote_state.subzone.outputs.subzone_name
}

output "externaldns_txt_owner_id" {
  description = "TXT marker owner ID — verify khi multi-cluster"
  value       = var.externaldns_txt_owner_id
}
