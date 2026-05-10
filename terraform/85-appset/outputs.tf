output "appproject_name" {
  description = "AppProject name (kubectl get appproject -n argocd)"
  value       = "shopxpress-pro"
}

output "appset_name" {
  description = "ApplicationSet name (kubectl get applicationset -n argocd)"
  value       = "shopxpress-pro"
}

output "workload_namespaces" {
  description = "3 namespace workload do TF tạo (dev/stg/prd)"
  value       = [for ns in kubectl_manifest.workload_namespace : ns.name]
}

output "expected_applications" {
  description = "9 Application Argo sẽ tự đẻ từ matrix generator (3 service × 3 env)"
  value = [
    for svc in ["gateway", "products", "orders"] :
    [for env in ["dev", "stg", "prd"] : "${svc}-${env}"]
  ]
}

output "manifest_repo_url" {
  description = "Repo Git ApplicationSet pull chart từ"
  value       = "https://github.com/DVM1987/shopxpress-pro-deploy.git"
}
