# ============================================================
# Đọc EKS outputs từ Sub-comp 2 (20-eks) — cluster endpoint + CA cho kubectl
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
# aws_eks_cluster_auth — fetch K8s API token cho kubectl provider.
# Token validity 15m, KHÔNG cần kubeconfig file.
# ============================================================
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}
