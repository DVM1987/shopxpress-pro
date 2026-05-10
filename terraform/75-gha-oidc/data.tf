# Account ID dùng để build sub claim + ARN reference
data "aws_caller_identity" "current" {}

# Live fetch TLS cert chain của GitHub OIDC endpoint → extract sha1 fingerprint.
# Senior pattern: KHÔNG hardcode thumbprint (xoay cert là phải sửa code).
# Sau 06/2023 thumbprint cosmetic nhưng aws_iam_openid_connect_provider
# vẫn require argument này → fetch live tránh stale.
data "tls_certificate" "github" {
  url = var.oidc_provider_url
}

# Đọc remote state 70-ecr lấy 3 ECR repo ARN cho permission policy.
# Pattern reuse output thay vì hardcode ARN (đổi env → đổi 1 chỗ).
data "terraform_remote_state" "ecr" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "70-ecr/terraform.tfstate"
    region = var.region
  }
}
