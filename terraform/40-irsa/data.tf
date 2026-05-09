# ============================================================
# Đọc EKS cluster outputs từ Sub-comp 2 — cần OIDC issuer URL
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
# Đọc Route 53 sub-zone outputs từ Sub-comp 7a — cần subzone_arn
# scope IAM policy của ExternalDNS (least-privilege).
# ============================================================
data "terraform_remote_state" "subzone" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "15-r53-subzone/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# tls_certificate — fetch root CA cert thumbprint của OIDC issuer
# ============================================================
# Tại sao cần `tls_certificate`?
#   IAM OIDC Provider yêu cầu `thumbprint_list` = SHA-1 cert chain
#   của OIDC issuer endpoint. AWS dùng thumbprint này để TLS-pin
#   khi STS gọi vào URL https://oidc.eks.<region>.amazonaws.com.
#
# Pattern naive: hardcode `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`
#   (CA root AWS phát) — sai khi AWS rotate cert.
#
# Pattern đúng: tls_certificate fetch cert runtime, lấy SHA1 root.
#   url phải là OIDC issuer URL (thêm /.well-known/openid-configuration
#   tự động được provider handle).
# ============================================================
data "tls_certificate" "eks_oidc" {
  url = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
}
