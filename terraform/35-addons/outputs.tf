# ============================================================
# Add-on identity — consumed by Sub-comp 5 IRSA (vpc-cni IRSA refactor)
# ============================================================

output "vpc_cni_addon_arn" {
  description = "vpc-cni Add-on ARN, dùng cho IRSA service_account_role_arn binding sau"
  value       = aws_eks_addon.vpc_cni.arn
}

output "vpc_cni_addon_version" {
  description = "vpc-cni version đã cài (resolve từ data.aws_eks_addon_version)"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "kube_proxy_addon_version" {
  description = "kube-proxy version đã cài"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "coredns_addon_version" {
  description = "coredns version đã cài"
  value       = aws_eks_addon.coredns.addon_version
}

# ============================================================
# Add-on configuration audit
# ============================================================

output "vpc_cni_configuration_values" {
  description = "vpc-cni configuration_values JSON đang active (audit Prefix Delegation enabled)"
  value       = aws_eks_addon.vpc_cni.configuration_values
  sensitive   = false
}
