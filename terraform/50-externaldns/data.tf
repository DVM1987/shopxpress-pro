# ============================================================
# Đọc EKS outputs từ Sub-comp 2 (20-eks) — cluster name + endpoint + CA
# ============================================================
# Helm provider 3.x cần 3 thứ để authenticate vào K8s API:
#   - host (cluster_endpoint)
#   - cluster_ca_certificate (base64-decoded từ certificate_authority_data)
#   - token (từ aws_eks_cluster_auth — refresh qua STS GetCallerIdentity)
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "20-eks/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# Đọc IRSA outputs từ Sub-comp 5 (40-irsa) — externaldns role ARN
# ============================================================
data "terraform_remote_state" "irsa" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "40-irsa/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# Đọc Sub-zone outputs từ Sub-comp 7a (15-r53-subzone) — domain filter
# ============================================================
# ExternalDNS dùng `domainFilters` để limit phạm vi hostname controller
# touch. Pass sub-zone name từ remote_state, KHÔNG hardcode → tránh
# drift khi đổi domain.
data "terraform_remote_state" "subzone" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "15-r53-subzone/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# aws_eks_cluster_auth — fetch K8s API token cho helm provider
# ============================================================
# Cluster authentication mode = API. Token refresh mỗi run TF (15 min validity)
# qua STS GetCallerIdentity sign request → EKS verify.
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}
