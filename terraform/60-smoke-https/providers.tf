# ============================================================
# Kubernetes provider — connect to EKS K8s API
# ============================================================
# 3 input authenticate (giống helm provider 3.x):
#   - host: K8s API endpoint
#   - cluster_ca_certificate: base64-decode CA cert để TLS-verify
#   - token: Bearer token (refresh mỗi 15 min qua aws_eks_cluster_auth)
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
