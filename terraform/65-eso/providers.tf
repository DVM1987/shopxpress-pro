# ============================================================
# Helm provider v3 — connect to EKS K8s API
# ============================================================
# Syntax v3 KHÁC v2:
#   v2: provider "helm" { kubernetes { host = ... } }   ← nested block
#   v3: provider "helm" { kubernetes = { host = ... } } ← argument (map)
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ============================================================
# Kubernetes provider — same auth pattern, 1 NS app-demo
# ============================================================
# Quản 1 resource duy nhất: kubernetes_namespace "app_demo".
# Tách khỏi helm release để lifecycle độc lập (helm uninstall KHÔNG xoá NS).
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# ============================================================
# kubectl provider — apply-time CRD validation
# ============================================================
# Dùng cho ClusterSecretStore + ExternalSecret (CRD instance), KHÔNG dùng
# kubernetes_manifest vì plan-time validate CRD (CRD chưa có lúc plan đầu).
# load_config_file=false: không đọc ~/.kube/config, chỉ dùng inline auth.
provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
