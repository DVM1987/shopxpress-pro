# ============================================================
# EKS Cluster control plane
# ============================================================
# Subnet placement: 3 private-app + 3 public (6 AZ slot)
#   - Control plane ENI (cross-account, AWS-managed) cần subnet để mount
#   - Public subnet cho phép sau này tạo internet-facing ALB qua AWS LBC
#   - Private-app cho internal-elb + worker node communication
# Endpoint mode: Public + Private
#   - Public restricted by CIDR whitelist (IP nhà admin)
#   - Private cho worker node + internal tooling đi qua VPC route
# ============================================================

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = concat(
      data.terraform_remote_state.vpc.outputs.private_app_subnet_ids,
      data.terraform_remote_state.vpc.outputs.public_subnet_ids,
    )
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # Modern access entry API (KHÔNG dùng aws-auth ConfigMap legacy)
  # bootstrap admin = caller (DE000189) → tự auto map system:masters
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Envelope encryption Secret etcd — IMMUTABLE (bật rồi không tắt được)
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Standard support — Extended +$0.60/h, dev không cần
  upgrade_policy {
    support_type = "STANDARD"
  }

  # ARC zonal shift — dev OFF, prod nên ON + autoshift
  zonal_shift_config {
    enabled = false
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(local.common_tags, {
    Component = "eks-control-plane"
    Name      = var.cluster_name
  })

  # Đảm bảo Log Group + IAM policy attach DONE trước khi cluster start log push
  # (race condition: cluster log push trước khi Log Group tồn tại = AWS auto-tạo retention=Never)
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster,
    aws_iam_role_policy_attachment.cluster_eks_policy,
  ]
}
