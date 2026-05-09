# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name (dev/stg/prd) — tag value"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Helm release config
# ============================================================

variable "lbc_chart_version" {
  description = "Chart version eks/aws-load-balancer-controller. Pin = reproducible. App version = chart version từ chart 3.x trở đi (LBC v3.3.0 = chart 3.3.0)."
  type        = string
  default     = "3.3.0"
}

variable "lbc_replica_count" {
  description = "Số replica controller. 2 cho HA (default chart). 1 cho dev cost-saving (chấp nhận downtime khi node restart)."
  type        = number
  default     = 2
}

variable "lbc_helm_timeout_seconds" {
  description = "Timeout chờ chart deploy thành công (pod Healthy + webhook ready). 600s đủ cho cluster lab; tăng nếu image pull chậm."
  type        = number
  default     = 600
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
  description = "Data sensitivity. Controller cluster-wide → confidential."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. Controller stateless → none."
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
