# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name. Sub-zone scope = nonprd (dev + stg shared cluster)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region. Route 53 là global service, region chỉ cần cho provider."
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# DNS config
# ============================================================

variable "apex_zone_name" {
  description = "Apex hosted zone name (no trailing dot). Sub-zone delegate từ zone này qua NS record."
  type        = string
  default     = "do2602.click"
}

variable "subzone_name" {
  description = "Sub-zone FQDN (no trailing dot). Pattern: <project>.<apex>"
  type        = string
  default     = "shopxpress-pro.do2602.click"
}

variable "delegation_ttl" {
  description = "TTL cho NS record delegation ở apex. 172800s (48h) std RFC 1912 cho NS record rare-change."
  type        = number
  default     = 172800
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
  description = "Data sensitivity. DNS public name → internal."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. R53 zone replicated by AWS → none."
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
