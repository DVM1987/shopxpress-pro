# ============================================================
# Node group identity — consumed by Sub-comp 4 IRSA, observability
# ============================================================

output "node_group_id" {
  description = "MNG ID format <cluster>:<nodegroup_name>"
  value       = aws_eks_node_group.default.id
}

output "node_group_arn" {
  description = "MNG ARN, dùng cho IAM policy resource"
  value       = aws_eks_node_group.default.arn
}

output "node_group_name" {
  description = "MNG name (without cluster prefix)"
  value       = aws_eks_node_group.default.node_group_name
}

output "node_group_status" {
  description = "MNG status (ACTIVE/CREATING/UPDATING/DELETING)"
  value       = aws_eks_node_group.default.status
}

# ============================================================
# Node IAM role — consumed by aws-auth audit, IRSA reference
# ============================================================

output "node_role_arn" {
  description = "Node IAM role ARN. Sub-comp 4+ tham chiếu cho aws-auth ConfigMap (legacy) hoặc access entry (modern)."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Node IAM role name (without ARN prefix)"
  value       = aws_iam_role.node.name
}

# ============================================================
# Launch template — debug + audit
# ============================================================

output "launch_template_id" {
  description = "Launch Template ID đang gắn vào MNG"
  value       = aws_launch_template.node.id
}

output "launch_template_latest_version" {
  description = "LT latest version. MNG dùng \"$Latest\" → version này = active"
  value       = aws_launch_template.node.latest_version
}

# ============================================================
# Auto Scaling Group — pass-through từ MNG resources
# ============================================================

output "autoscaling_group_names" {
  description = "ASG names AWS auto-tạo bên dưới MNG. Dùng cho Cluster Autoscaler discovery hoặc Karpenter sau migrate."
  value       = [for r in aws_eks_node_group.default.resources[0].autoscaling_groups : r.name]
}
