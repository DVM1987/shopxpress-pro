# ============================================================
# Trust policy — STS verify JWT pod khi pod gọi AssumeRoleWithWebIdentity
# ============================================================
# 4 điều kiện then chốt:
#   1. Action = sts:AssumeRoleWithWebIdentity
#   2. Principal Federated = OIDC Provider ARN (đăng ký trong IAM)
#   3. Condition <oidc>:sub = system:serviceaccount:<ns>:<sa> — chốt đúng SA
#   4. Condition <oidc>:aud = sts.amazonaws.com — chốt đúng audience
# Thiếu condition aud = role có thể bị bất kỳ JWT nào assume (security hole).
# replace() strip https:// vì IAM condition key dạng <issuer-host>:sub không có scheme.
# ============================================================

locals {
  oidc_provider_url_stripped = replace(var.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowSAAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:${var.sa_namespace}:${var.sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url_stripped}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ============================================================
# IAM role — pod assumes via JWT
# ============================================================
resource "aws_iam_role" "this" {
  name        = var.role_name
  description = var.role_description

  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = var.tags
}

# ============================================================
# Policy attachment — count cho multi-policy
# ============================================================
# Tại sao count thay vì for_each(toset)?
#   for_each(toset) HASH giá trị làm key. Khi caller pass ARN policy
#   chưa biết tại plan time (vd `aws_iam_policy.lbc.arn` resource cùng
#   apply), toset không tính được key set → TF báo "Invalid for_each".
#   count chỉ cần length(list), known at plan time (1, 2, 3...) kể cả
#   khi value chưa biết. Trade-off: đổi thứ tự list = TF destroy+recreate
#   attachment ở index thay đổi. Cho IRSA module attachment chỉ là metadata,
#   recreate zero-downtime — chấp nhận được.
# ============================================================
resource "aws_iam_role_policy_attachment" "this" {
  count = length(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}
