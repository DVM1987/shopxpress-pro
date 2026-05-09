# ============================================================
# Đọc EKS outputs (20-eks) — cluster endpoint + CA cho K8s provider
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
# Đọc Sub-zone outputs (15-r53-subzone) — host suffix
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
# Đọc ACM outputs (55-acm) — cert ARN cho ALB listener 443
# ============================================================
data "terraform_remote_state" "acm" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "55-acm/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# K8s API token — refresh mỗi run TF (15 min)
# ============================================================
data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}
