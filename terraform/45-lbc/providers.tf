# ============================================================
# Helm provider v3 — connect to EKS K8s API
# ============================================================
# Syntax v3 KHÁC v2:
#   v2: provider "helm" { kubernetes { host = ... } }   ← nested block
#   v3: provider "helm" { kubernetes = { host = ... } } ← argument (map)
#
# Lý do AWS chọn v3 từ đầu (chốt 2026-05-09):
#   1. Tránh bug `invalid_reference` của 2.17 với Bitnami chart
#      (project_helm_provider_3_migration.md)
#   2. v3 là long-term — v2 sẽ deprecate
#
# 3 input authenticate:
#   - host: K8s API endpoint (https://<cluster-id>.gr7.<region>.eks.amazonaws.com)
#   - cluster_ca_certificate: base64-decode CA cert để TLS-verify endpoint
#   - token: Bearer token (refresh mỗi 15 min qua aws_eks_cluster_auth)
# ============================================================
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
