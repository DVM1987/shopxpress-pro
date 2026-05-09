# ============================================================
# EKS Cluster IAM Role
# ============================================================
# Role này EKS service assume để gọi AWS API thay user:
#   - DescribeVpcs/Subnets, tạo cluster SG, tạo ENI control plane
#   - CreateServiceLinkedRole cho ELB (1 lần/account)
#   - DescribeKey verify KMS (Encrypt/Decrypt nằm ở key policy, không ở đây)
# Trust principal: eks.amazonaws.com (KHÔNG phải EC2 — đó là node role)
# ============================================================

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    sid     = "EKSClusterAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name        = "${local.name_prefix}-cluster-role"
  description = "EKS control plane service role for cluster ${var.cluster_name}"

  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role.json
  max_session_duration  = 3600
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Component = "eks-cluster-role"
  })
}

# AmazonEKSClusterPolicy — AWS-managed, 3 statement (verified Console 2026-05-02)
# 70% action là legacy CCM (ELB Classic + EBS in-tree + Cluster Autoscaler v1)
# 30% action active: EC2 Describe + SG Create/Modify + ENI tag + KMS DescribeKey
resource "aws_iam_role_policy_attachment" "cluster_eks_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}
