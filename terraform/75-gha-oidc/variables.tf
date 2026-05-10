# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name (dùng cho tag)"
  type        = string
  default     = "nonprd"
}

variable "region" {
  description = "AWS region (IAM là global, region chỉ ảnh hưởng provider config)"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# GitHub OIDC config
# ============================================================

variable "github_org" {
  description = "GitHub org/user owning repo. Format sub claim: repo:<org>/<repo>:..."
  type        = string
  default     = "DVM1987"
}

variable "github_repo" {
  description = "Repo app GHA workflow chạy. KHÔNG phải repo IaC. Lab A++ workflow build-push trong repo app."
  type        = string
  default     = "shopxpress-pro-app"
}

variable "github_branch_pattern" {
  description = "Pattern branch được assume role. * = mọi branch (lab convenience). Production: 'main' hoặc dùng GHA Environment gate."
  type        = string
  default     = "*"
}

variable "oidc_provider_url" {
  description = "URL OIDC IdP GitHub Actions. Cố định (không đổi giữa repos), match iss claim trong JWT."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "oidc_audience" {
  description = "Audience JWT. AWS = sts.amazonaws.com (cố định). aws-actions/configure-aws-credentials@v4 set audience này mặc định."
  type        = string
  default     = "sts.amazonaws.com"
}

# ============================================================
# Read-only override
# ============================================================

variable "tfstate_bucket" {
  description = "S3 bucket TF state (đọc remote state 70-ecr lấy ECR repo ARN)"
  type        = string
  default     = "shopxpress-pro-tfstate-527055790396-apse1"
}

# ============================================================
# Tagging — governance / finops / audit
# ============================================================

variable "owner" {
  description = "IAM user / team chịu trách nhiệm"
  type        = string
  default     = "DE000189"
}

variable "cost_center" {
  description = "Cost center cho billing"
  type        = string
  default     = "engineering"
}

variable "repo_url" {
  description = "Git repo URL của IaC code"
  type        = string
  default     = "https://github.com/DVM1987/shopxpress-pro"
}

variable "data_classification" {
  description = "OIDC role có quyền push/pull image production → confidential"
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "IAM resource không có data → none"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "daily", "weekly", "critical"], var.backup_policy)
    error_message = "backup_policy must be one of: none, daily, weekly, critical."
  }
}

variable "created_by" {
  description = "Person/team đã tạo (audit trail)"
  type        = string
  default     = "DE000189"
}
