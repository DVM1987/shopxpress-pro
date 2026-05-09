# ============================================================
# OIDC Provider — consumed by future IRSA roles (LBC/ExternalDNS/ESO)
# ============================================================

output "oidc_provider_arn" {
  description = "IAM OIDC Provider ARN — input cho mọi IRSA role sau (LBC, ExternalDNS, ESO, ebs-csi)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL (có https://) — input cho IRSA module"
  value       = local.oidc_issuer_url
}

# ============================================================
# vpc-cni IRSA — consumed by Sub-comp 35-addons (re-apply gắn vào Add-on)
# ============================================================

output "vpc_cni_irsa_role_arn" {
  description = "IAM role ARN cho aws-node SA. Set vào aws_eks_addon.vpc_cni.service_account_role_arn."
  value       = module.vpc_cni_irsa.role_arn
}

output "vpc_cni_irsa_role_name" {
  description = "vpc-cni IRSA role name (cho audit/cleanup)"
  value       = module.vpc_cni_irsa.role_name
}

# ============================================================
# ebs-csi IRSA — consumed by Sub-comp 35-addons (aws-ebs-csi-driver)
# ============================================================

output "ebs_csi_irsa_role_arn" {
  description = "IAM role ARN cho ebs-csi-controller-sa. Set vào aws_eks_addon.aws_ebs_csi_driver.service_account_role_arn."
  value       = module.ebs_csi_irsa.role_arn
}

output "ebs_csi_irsa_role_name" {
  description = "ebs-csi IRSA role name (cho audit/cleanup)"
  value       = module.ebs_csi_irsa.role_name
}

# ============================================================
# LBC IRSA — consumed by Sub-comp 45-lbc (helm_release SA annotation)
# ============================================================

output "lbc_irsa_role_arn" {
  description = "IAM role ARN cho aws-load-balancer-controller SA. Set vào helm_release values serviceAccount.annotations."
  value       = module.lbc_irsa.role_arn
}

output "lbc_irsa_role_name" {
  description = "LBC IRSA role name (cho audit/cleanup)"
  value       = module.lbc_irsa.role_name
}

output "lbc_iam_policy_arn" {
  description = "Customer-managed policy ARN cho LBC (cho audit/cleanup)"
  value       = aws_iam_policy.lbc.arn
}

# ============================================================
# ExternalDNS IRSA — consumed by Sub-comp 50-externaldns
# ============================================================

output "externaldns_irsa_role_arn" {
  description = "IAM role ARN cho external-dns SA. Set vào helm_release values serviceAccount.annotations."
  value       = module.externaldns_irsa.role_arn
}

output "externaldns_irsa_role_name" {
  description = "ExternalDNS IRSA role name (cho audit/cleanup)"
  value       = module.externaldns_irsa.role_name
}

output "externaldns_iam_policy_arn" {
  description = "Customer-managed policy ARN cho ExternalDNS (cho audit/cleanup)"
  value       = aws_iam_policy.externaldns.arn
}
