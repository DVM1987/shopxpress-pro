# ============================================================
# Helm provider v3 — connect to EKS K8s API
# ============================================================
# Syntax v3 KHÁC v2:
#   v2: provider "helm" { kubernetes { host = ... } }   ← nested block
#   v3: provider "helm" { kubernetes = { host = ... } } ← argument (map)
#
# 3 input authenticate:
#   - host: K8s API endpoint
#   - cluster_ca_certificate: base64-decode CA cert để TLS-verify endpoint
#   - token: Bearer token (refresh mỗi 15 min qua aws_eks_cluster_auth)
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
