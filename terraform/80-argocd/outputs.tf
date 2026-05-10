output "argocd_release_name" {
  description = "Helm release name (cho audit/troubleshooting kubectl)"
  value       = helm_release.argocd.name
}

output "argocd_release_namespace" {
  description = "Namespace ArgoCD chạy"
  value       = helm_release.argocd.namespace
}

output "argocd_release_version" {
  description = "Chart version đã deploy"
  value       = helm_release.argocd.version
}

output "argocd_release_app_version" {
  description = "App version (image tag ArgoCD)"
  value       = helm_release.argocd.metadata.app_version
}

output "argocd_url" {
  description = "URL public truy cập ArgoCD UI/API qua ALB IngressGroup shopxpress-pro-public"
  value       = "https://argocd.shopxpress-pro.do2602.click"
}

output "argocd_ingress_name" {
  description = "Ingress object name (kubectl get ingress -n argocd)"
  value       = "argocd-server"
}
