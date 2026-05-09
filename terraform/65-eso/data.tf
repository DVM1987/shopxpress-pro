# ============================================================
# Đọc EKS outputs từ Sub-comp 2 (20-eks) — cluster + endpoint + CA
# ============================================================
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "20-eks/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# Đọc IRSA outputs từ Sub-comp 5 (40-irsa) — OIDC provider ARN + URL
# ============================================================
# 40-irsa centralize OIDC Provider (1 resource cho cả cluster).
# 65-eso đọc oidc_provider_arn + oidc_provider_url để truyền vào module
# IRSA inline (tạo IAM role cho ESO controller).
#
# Tradeoff so với pattern centralize toàn bộ IRSA role trong 40-irsa:
#   - Centralize: 1 nơi nhìn hết IRSA role, dễ audit. Nhược điểm: thêm
#     1 role = sửa 40-irsa + apply lại + add output.
#   - Inline: mỗi sub-comp tự own IRSA role của nó, cleanup gọn (terraform
#     destroy 65-eso = xoá hết). Nhược điểm: phân tán, audit phải đọc
#     nhiều state file.
# ESO chọn inline vì Sub-comp 9 = standalone module, dependency rõ ràng.
data "terraform_remote_state" "irsa" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "40-irsa/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# aws_eks_cluster_auth — fetch K8s API token cho helm + kubernetes provider
# ============================================================
# Token validity 15m (STS GetCallerIdentity sign request → EKS verify).
# Refresh tự động mỗi run TF, KHÔNG cần kubeconfig file.
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}
