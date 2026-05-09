# ============================================================
# Node IAM Role
# ============================================================
# Role này EC2 instance (worker node) assume để gọi AWS API:
#   - kubelet ↔ EKS control plane (Describe* cho kubelet auth qua IAM)
#   - vpc-cni: ec2:Describe/AssignPrivateIpAddresses/UnassignPrivateIpAddresses
#   - kube-proxy: không cần extra permission, in-cluster
#   - SSM Agent: ssmmessages/ec2messages (Session Manager exec node)
#   - ECR pull image: ecr:GetAuthorizationToken + GetDownloadUrlForLayer
# Trust principal: ec2.amazonaws.com (KHÔNG eks — đó là cluster role)
# ============================================================

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    sid     = "EKSNodeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name        = "${local.name_prefix}-node-role"
  description = "EKS node role for MNG ${var.node_group_name} on cluster ${local.cluster_name}"

  assume_role_policy    = data.aws_iam_policy_document.node_assume_role.json
  max_session_duration  = 3600
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Component = "eks-mng-node-role"
  })
}

# ============================================================
# 4 AWS-managed policy attach
# ============================================================
# AmazonEKSWorkerNodePolicy:
#   - eks:DescribeCluster (kubelet bootstrap đọc cluster CA + endpoint)
#   - ec2:Describe* (kubelet self-discover)
#
# AmazonEKS_CNI_Policy:
#   - ec2:AssignPrivateIpAddresses, UnassignPrivateIpAddresses
#   - ec2:DescribeInstances, DescribeInstanceTypes (vpc-cni Prefix Delegation)
#   - ec2:CreateNetworkInterface (warm pool ENI)
# Note: Best practice production = chuyển sang IRSA cho aws-node DaemonSet,
# tách permission khỏi node role. Đang giữ ở node role cho đơn giản
# (Sub-comp 4 sẽ refactor nếu cần).
#
# AmazonEC2ContainerRegistryReadOnly:
#   - ecr:GetAuthorizationToken, BatchGetImage, GetDownloadUrlForLayer
#   - Cho containerd pull image private ECR
#
# AmazonSSMManagedInstanceCore:
#   - ssmmessages:*, ec2messages:* (Session Manager)
#   - Pattern production: SSH OFF, debug node qua `aws ssm start-session`
# ============================================================

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
