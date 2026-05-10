# ============================================================
# EKS outputs — cluster_id + endpoint + CA cho 2 provider authenticate
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
# K8s API token — refresh mỗi run TF (15m), KHÔNG cần kubeconfig file
# ============================================================
data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}
