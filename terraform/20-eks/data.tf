# ============================================================
# Read VPC outputs từ Sub-comp 1 state (S3 backend)
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
# Account context — dùng trong KMS key policy + IAM trust
# ============================================================
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
