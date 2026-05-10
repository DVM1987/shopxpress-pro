# ============================================================
# Helm + Kubernetes provider — connect EKS K8s API
# ============================================================
# Cùng auth pattern với 45-lbc / 50-externaldns / 65-eso:
#   - host từ EKS cluster_endpoint
#   - cluster_ca_certificate từ certificate_authority_data (base64-decoded)
#   - token refresh mỗi run TF qua aws_eks_cluster_auth (15m validity)
#
# 2 provider cùng auth source — Helm để cài Bitnami chart, Kubernetes
# để tạo Namespace + StorageClass (cluster-scoped object).
# ============================================================
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
