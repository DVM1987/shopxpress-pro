locals {
  name_prefix = "${var.project}-${var.env}"

  # Tên resource — đặt 1 chỗ
  idp_name      = "token.actions.githubusercontent.com"
  role_name     = "${local.name_prefix}-gha-ecr-push"
  policy_name   = "${local.name_prefix}-gha-ecr-push"

  # Sub claim 2 format GitHub Actions cấp:
  # - Push branch: repo:OWNER/REPO:ref:refs/heads/<pattern>
  # - Pull request: repo:OWNER/REPO:pull_request (KHÔNG có ref)
  # Trust phải cover cả 2 vì workflow build-push.yml chạy trên cả push + PR.
  github_sub_patterns = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch_pattern}",
    "repo:${var.github_org}/${var.github_repo}:pull_request",
  ]

  # 3 ECR repo ARN từ remote state 70-ecr (gateway, products, orders)
  ecr_repo_arns = values(data.terraform_remote_state.ecr.outputs.repository_arns)

  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "gha-oidc"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
