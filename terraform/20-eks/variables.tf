# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name (dev/stg/prd) — tag value, not part of cluster name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Cluster
# ============================================================

variable "cluster_name" {
  description = "EKS cluster name. Immutable. nonprd suffix vì cluster serve cả NS dev + stg."
  type        = string
  default     = "shopxpress-pro-nonprd-eks"
}

variable "cluster_version" {
  description = "Kubernetes version. N-1 = 1.34, standard support đến 2026-12-02"
  type        = string
  default     = "1.34"
}

variable "endpoint_public_access_cidrs" {
  description = "Whitelist CIDR cho public endpoint API server (kubectl từ máy admin). ISP cấp IP động → cập nhật khi đổi."
  type        = list(string)
  default     = ["113.22.28.87/32"]
}

variable "cluster_enabled_log_types" {
  description = "Control plane log types push lên CloudWatch. api+audit đủ cho dev (3 type còn lại tốn $$$ ít giá trị debug)."
  type        = list(string)
  default     = ["api", "audit"]

  validation {
    condition = alltrue([
      for t in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)
    ])
    error_message = "cluster_enabled_log_types phải là subset của: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cluster_log_retention_days" {
  description = "CloudWatch Log Group retention. 30 ngày = balance giữa $$$ và debug window"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention_days)
    error_message = "cluster_log_retention_days phải là 1 trong các giá trị CloudWatch hợp lệ (1/3/5/7/14/30/60/90/120/150/180/365/400/545/731/1827/3653)."
  }
}

# ============================================================
# Tagging — governance / finops / audit (giống Sub-comp 1)
# ============================================================

variable "owner" {
  description = "IAM user / team chịu trách nhiệm resource (alerts, on-call)"
  type        = string
  default     = "DE000189"
}

variable "cost_center" {
  description = "Cost center / department cho billing chargeback"
  type        = string
  default     = "engineering"
}

variable "repo_url" {
  description = "Git repo URL của IaC code (traceability tag)"
  type        = string
  default     = "https://github.com/DVM1987/shopxpress-pro"
}

variable "data_classification" {
  description = "Data sensitivity: public/internal/confidential/restricted. EKS chứa secret K8s → mặc định confidential"
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy: none/daily/weekly/critical. EKS control plane stateless → none (etcd AWS-managed)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "daily", "weekly", "critical"], var.backup_policy)
    error_message = "backup_policy must be one of: none, daily, weekly, critical."
  }
}

variable "created_by" {
  description = "Person/team đã tạo resource (audit trail)"
  type        = string
  default     = "DE000189"
}
