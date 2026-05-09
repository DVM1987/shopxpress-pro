# ============================================================
# Read VPC outputs từ Sub-comp 1 state (S3 backend)
# Cần: private_app_subnet_ids để place node 3 AZ
# ============================================================
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "10-vpc/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# Read EKS outputs từ Sub-comp 2 state (S3 backend)
# Cần: cluster_id để gắn MNG, cluster_version cho compatibility
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
# Account context — dùng trong IAM Role ARN format
# ============================================================
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
