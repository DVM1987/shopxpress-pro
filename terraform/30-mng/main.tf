# ============================================================
# EKS Managed Node Group
# ============================================================
# MNG vs Self-managed NG:
#   - MNG = AWS quản lý ASG + LT bootstrap + drain + health replacement
#   - Self-managed = bạn tự build ASG + bootstrap script + lifecycle hook
# MNG tradeoff: ít control hơn (không tự custom kubelet flag tuỳ ý) nhưng
# vận hành rẻ. Production senior: MNG cho default workload, Self-managed
# chỉ khi có yêu cầu kubelet flag custom hoặc OS image lock.
#
# Subnet placement: 3 private-app (1a/1b/1c). KHÔNG đặt vào public vì:
#   - Worker không cần Public IP (egress qua NAT)
#   - Private subnet = compliance baseline (PCI/SOC 2)
# Egress phụ thuộc NAT Gateway zonal Sub-comp 1 (single NAT, NAT down =
# 3 AZ private-app mất Internet — chấp nhận trade-off lab).
# ============================================================

resource "aws_eks_node_group" "default" {
  cluster_name    = local.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn

  # 3 private-app subnet từ Sub-comp 1
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnet_ids

  # ----------------------------------------------------------
  # Launch template wiring
  # ----------------------------------------------------------
  # MNG đọc LT theo id + version. version="$Latest" = MNG luôn pickup
  # version mới nhất khi LT update, KHÔNG cần TF apply lại MNG.
  # Trade-off: LT update bằng tay → MNG tự rolling update (tốt cho hot patch).
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  # ----------------------------------------------------------
  # Capacity / instance type
  # ----------------------------------------------------------
  # ami_type + instance_types ở MNG-level (KHÔNG set trong LT → MNG control).
  # capacity_type ON_DEMAND vs SPOT.
  ami_type       = var.ami_type
  capacity_type  = var.capacity_type
  instance_types = var.instance_types
  # disk_size: KHÔNG set ở đây vì đã spec trong LT block_device_mappings.
  # Nếu set cả 2, conflict → MNG fail.

  # ----------------------------------------------------------
  # Scaling
  # ----------------------------------------------------------
  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  # Update strategy: rolling 1 node max unavailable. Mặc định cũng vậy
  # nhưng spec explicit cho rõ intent.
  update_config {
    max_unavailable = 1
  }

  # ----------------------------------------------------------
  # Labels — set ở MNG-level (KHÔNG ở user_data NodeConfig) cho
  # ----------------------------------------------------------
  # AWS-managed labels. Pod scheduler đọc qua kubelet API.
  # Memory: --node-labels= cũng được, nhưng MNG-level rõ intent + audit qua
  # describe-nodegroup, không cần ssh vào node.
  labels = var.node_labels

  # KHÔNG taint — workload general-purpose (Karpenter sau sẽ dùng taint riêng)

  # ----------------------------------------------------------
  # Lifecycle
  # ----------------------------------------------------------
  # ignore_changes desired_size: HPA / Cluster Autoscaler / Karpenter sẽ
  # mutate desired_size runtime. Không ignore = TF apply tiếp theo sẽ revert
  # về tfvars, gây flap node liên tục.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = merge(local.common_tags, {
    Component = "eks-mng"
    Name      = "${local.cluster_name}-${var.node_group_name}-mng"
  })

  # MNG creation phải sau khi 4 policy attach xong (race condition):
  # nếu MNG launch instance trước khi policy attach → kubelet bootstrap fail
  # vì thiếu eks:DescribeCluster.
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]
}
