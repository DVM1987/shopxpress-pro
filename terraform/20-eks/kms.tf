# ============================================================
# KMS key cho EKS Secret envelope encryption + CloudWatch Log Group
# ============================================================
# Envelope flow:
#   - DEK (random AES) encrypt secret content → ciphertext lưu etcd
#   - KEK (KMS key này) encrypt DEK → encrypted DEK lưu kèm
#   - Plaintext DEK chỉ trong RAM control plane, discard ngay
# IMMUTABLE: bật rồi KHÔNG tắt được. Key delete = secret etcd mất vĩnh viễn.
# ============================================================

data "aws_iam_policy_document" "eks_kms_key_policy" {
  # Statement 1 — Enable IAM User Permissions
  # Mở khoá để IAM policy attach vào user/role có hiệu lực (root = account)
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Statement 2 — Key Administrators (separation of duties: admin KHÔNG Encrypt)
  statement {
    sid    = "AllowKeyAdministrators"
    effect = "Allow"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }

  # Statement 3 — Key Users (Encrypt/Decrypt thật cho secret data)
  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }

  # Statement 4 — Allow Grant (cho EKS service tự CreateGrant lúc cluster create)
  # Dual authorization: user phải có IAM kms:CreateGrant + key policy phải allow
  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # Statement 5 — CloudWatch Logs service principal encrypt log stream
  # Log Group dùng cùng KMS key này. Thiếu = CreateLogGroup fail
  # AccessDenied với message "Cannot create LogGroup encrypted with KMS"
  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/cluster"]
    }
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS ${var.cluster_name} secrets envelope encryption + CloudWatch Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.eks_kms_key_policy.json

  tags = merge(local.common_tags, {
    Component = "eks-secrets-kms"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.eks.key_id
}
