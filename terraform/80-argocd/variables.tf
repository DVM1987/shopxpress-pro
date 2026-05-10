# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment scope (cluster nonprd shared dev+stg)"
  type        = string
  default     = "nonprd"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Helm release config
# ============================================================

variable "argocd_chart_version" {
  description = "Chart version argo/argo-cd. Mapping chart 9.5.12 → app v3.4.1, verify qua `helm search repo argo/argo-cd --versions` 2026-05-10."
  type        = string
  default     = "9.5.12"
}

variable "argocd_helm_timeout_seconds" {
  description = "Timeout chờ chart deploy thành công. ArgoCD 5 deployment + 3 CRD + ~30 RBAC, 600s đủ cho image pull lần đầu."
  type        = number
  default     = 600
}

# ============================================================
# Tagging — governance / finops / audit (10-tag enterprise)
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
  description = "Data sensitivity. ArgoCD touch deploy state nhưng không persist credential workload → confidential (thấp hơn ESO restricted)."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. ArgoCD state (Application object) reproducible từ Git → none."
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
