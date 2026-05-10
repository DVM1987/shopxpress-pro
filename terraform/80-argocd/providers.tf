# ============================================================
# Helm provider v3 — connect to EKS K8s API via STS token (15m TTL)
# Syntax v3: `kubernetes = { ... }` (argument), KHÔNG nested block như v2.
# ============================================================
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ============================================================
# kubectl provider — apply Ingress manifest
# load_config_file=false: chỉ dùng inline auth, KHÔNG đọc ~/.kube/config
# ============================================================
provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
