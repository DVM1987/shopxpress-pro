# ============================================================
# Đọc VPC outputs từ Sub-comp 1 (10-vpc) — cần vpc_id cho LBC
# ============================================================
# LBC `clusterName` là enough để controller tự discover VPC qua EKS API.
# Tuy nhiên hardcode `vpcId` vào values là production best-practice:
#   1. Loại bỏ 1 EC2 DescribeInstances call mỗi reconcile (latency + IAM)
#   2. Fail-fast nếu VPC không match (vd misconfig multi-cluster)
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
# Đọc EKS outputs từ Sub-comp 2 (20-eks) — cluster name + endpoint + CA
# ============================================================
# Helm provider 3.x cần 3 thứ để authenticate vào K8s API:
#   - host (cluster_endpoint)
#   - cluster_ca_certificate (base64-decoded từ certificate_authority_data)
#   - token (từ aws_eks_cluster_auth — tự refresh qua STS GetCallerIdentity)
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
# Đọc IRSA outputs từ Sub-comp 5 (40-irsa) — LBC role ARN
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
# aws_eks_cluster_auth — fetch K8s API token cho helm provider
# ============================================================
# Cluster authentication mode = API (Sub-comp 2). LBC TF apply chạy với
# IAM user DE000189 đã map system:masters trong access entry.
#
# Token này refresh mỗi run TF (15 min validity) — KHÔNG cần exec hook.
# Token được generate qua STS GetCallerIdentity sign request → EKS verify.
#
# Alternative (KHÔNG dùng): exec block gọi `aws eks get-token` runtime.
# Cách exec đó tốt cho long-running provider (Argo CD), không cần cho TF
# apply 1 lần.
# ============================================================
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}
