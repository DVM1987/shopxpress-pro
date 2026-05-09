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
# Add-on toggles
# ============================================================

variable "enable_prefix_delegation" {
  description = "vpc-cni: bật Prefix Delegation (1 ENI cấp /28 prefix = 16 IP thay 1 IP). Unlock max-pods t3.medium 110 thay 17."
  type        = bool
  default     = true
}

variable "warm_prefix_target" {
  description = "vpc-cni: số prefix /28 warm pool sẵn (giảm latency cold-start pod). 1 = đủ cho dev workload nhỏ."
  type        = number
  default     = 1
}

variable "addon_resolve_conflicts" {
  description = "Strategy khi Add-on collide với resource self-managed sẵn có. OVERWRITE = thay luôn (phù hợp Sub-comp 4 vì cluster có sẵn aws-node + kube-proxy default)."
  type        = string
  default     = "OVERWRITE"

  validation {
    condition     = contains(["NONE", "OVERWRITE", "PRESERVE"], var.addon_resolve_conflicts)
    error_message = "addon_resolve_conflicts phải là NONE, OVERWRITE, hoặc PRESERVE."
  }
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
  description = "Data sensitivity. Add-on system component → confidential."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. Add-on stateless → none."
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
