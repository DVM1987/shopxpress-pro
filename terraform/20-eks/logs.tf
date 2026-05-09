# ============================================================
# CloudWatch Log Group cho EKS control plane logs
# ============================================================
# Log Group name BẮT BUỘC = /aws/eks/<cluster-name>/cluster
# (EKS push log thẳng vào path này, không config được)
# Tạo trước cluster để gán retention + KMS encrypt; nếu không AWS auto-tạo
# với retention=Never (lưu vĩnh viễn → đốt $$$).
# ============================================================

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(local.common_tags, {
    Component = "eks-cluster-logs"
  })
}
