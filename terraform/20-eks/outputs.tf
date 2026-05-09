# ============================================================
# Cluster identity — consumed by Sub-comp 3 MNG, 4 IRSA, kubectl
# ============================================================

output "cluster_id" {
  description = "EKS cluster name (= identifier in AWS API)"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "EKS cluster ARN, used in IAM policy resource"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "K8s API server endpoint (kubectl + controller targets)"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert, used by kubeconfig + IRSA verifier"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "K8s minor version actually running"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster SG (control plane ↔ node communication)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# ============================================================
# OIDC — consumed by Sub-comp 4 IRSA (IAM OIDC Provider + role trust)
# ============================================================

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL — input cho aws_iam_openid_connect_provider"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# ============================================================
# Supporting resources — consumed by Sub-comp 3+ và observability
# ============================================================

output "kms_key_arn" {
  description = "KMS key ARN cho secret envelope encryption + Log Group encrypt"
  value       = aws_kms_key.eks.arn
}

output "kms_key_alias" {
  description = "KMS alias name (alias/<cluster>)"
  value       = aws_kms_alias.eks.name
}

output "cluster_role_arn" {
  description = "Cluster service role ARN — reference cho audit/troubleshooting"
  value       = aws_iam_role.cluster.arn
}

output "cluster_log_group_name" {
  description = "CloudWatch Log Group name cho control plane logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}
