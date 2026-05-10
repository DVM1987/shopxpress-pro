# ============================================================
# 1. IAM Identity Provider — GitHub OIDC
# ============================================================
# Singleton per account. Trust nhiều repo/branch qua trust policy
# của Role chứ KHÔNG qua IdP (IdP chỉ "AWS biết GitHub là gì").
resource "aws_iam_openid_connect_provider" "github" {
  url             = var.oidc_provider_url
  client_id_list  = [var.oidc_audience]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name = local.idp_name
  }
}

# ============================================================
# 2. IAM Permission Policy — ECR push 3 repo
# ============================================================
# 2 statement vì ecr:GetAuthorizationToken không scope resource được
# (limitation API), action khác scope theo ARN repo.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
    ]
    resources = local.ecr_repo_arns
  }
}

resource "aws_iam_policy" "ecr_push" {
  name        = local.policy_name
  description = "Allow GHA OIDC role push/pull ${length(local.ecr_repo_arns)} ECR repos for project ${var.project}"
  policy      = data.aws_iam_policy_document.ecr_push.json
}

# ============================================================
# 3. IAM Role — trust GitHub OIDC + attach policy
# ============================================================
# Trust policy: chỉ workflow chạy trong <org>/<repo> branch pattern
# được phép sts:AssumeRoleWithWebIdentity.
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "GitHubOIDCAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # aud BẮT BUỘC: chốt audience tránh token issuer khác assume nhầm
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = [var.oidc_audience]
    }

    # sub BẮT BUỘC: scope theo repo + branch pattern + PR. List 2 value:
    # - branch push (refs/heads/*) → cho push main → push ECR
    # - pull_request → cho PR run → build + scan (KHÔNG push, gate by if step)
    # Wildcard ở branch pattern → dùng StringLike (StringEquals KHÔNG hỗ trợ).
    condition {
      test     = "StringLike"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = local.github_sub_patterns
    }
  }
}

resource "aws_iam_role" "gha_ecr_push" {
  name               = local.role_name
  description        = "Role assumed by GHA OIDC from ${var.github_org}/${var.github_repo} branches ${var.github_branch_pattern}"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  # Max session duration 1h (default 1h). Build push thường < 10 min,
  # 1h dư. Production lengthy job có thể tăng (max 12h).
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.gha_ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}
