# ============================================================
# kubectl provider — apply Namespace + AppProject + ApplicationSet
# load_config_file=false: chỉ dùng inline auth, KHÔNG đọc ~/.kube/config
# Token validity 15m, refresh tự động mỗi run TF qua data.aws_eks_cluster_auth.
# ============================================================
provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
