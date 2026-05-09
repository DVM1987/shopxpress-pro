# ============================================================
# Read EKS outputs từ Sub-comp 2 state — cần cluster_id + version
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
# Read MNG outputs từ Sub-comp 3 state — depends_on (gián tiếp)
# ============================================================
# Tại sao đọc state Sub-comp 3 dù không cần output cụ thể nào?
#   → coredns Add-on là Deployment (KHÔNG phải DaemonSet), pod KHÔNG schedule
#     được nếu chưa có node Ready. Đọc state Sub-comp 3 = TF chỉ apply Sub-comp
#     4 sau khi 30-mng đã apply xong.
#   → Pattern an toàn: caller làm `make apply COMPONENT=30-mng` trước, rồi
#     mới `make apply COMPONENT=35-addons` (TF không enforce thứ tự xuyên
#     state, chỉ tham chiếu output bằng remote_state).
# ============================================================
data "terraform_remote_state" "mng" {
  backend = "s3"
  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "30-mng/terraform.tfstate"
    region = var.region
  }
}

# ============================================================
# Read IRSA outputs từ Sub-comp 5 state — vpc-cni IRSA role
# ============================================================
# Pattern: 40-irsa apply trước, expose role_arn qua output.
# 35-addons re-apply để wire role_arn vào Add-on field
# `service_account_role_arn` → aws-node SA chuyển từ node role → IRSA role.
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
# Resolve addon version compatible với cluster_version
# ============================================================
# `most_recent=true` → AWS trả về version mới nhất TRONG range support
# cho cluster_version hiện tại. Pattern này tự động bump version khi
# cluster upgrade lên 1.35/1.36 — KHÔNG cần sửa tfvars.
# ============================================================

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = data.terraform_remote_state.eks.outputs.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = data.terraform_remote_state.eks.outputs.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = data.terraform_remote_state.eks.outputs.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "aws_ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = data.terraform_remote_state.eks.outputs.cluster_version
  most_recent        = true
}
