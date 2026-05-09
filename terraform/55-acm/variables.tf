# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name. Cert scope = nonprd."
  type        = string
  default     = "nonprd"
}

variable "region" {
  description = "AWS region. Cert PHẢI cùng region với ALB consume cert. Nếu sau dùng CloudFront, cần cert thứ 2 ở us-east-1 (folder riêng)."
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Cert config
# ============================================================

variable "key_algorithm" {
  description = "Cert key algorithm. RSA_2048 = default, max compat. EC_prime256v1 nhẹ hơn nhưng vài client cũ không hỗ trợ."
  type        = string
  default     = "RSA_2048"

  validation {
    condition     = contains(["RSA_2048", "RSA_3072", "RSA_4096", "EC_prime256v1", "EC_secp384r1", "EC_secp521r1"], var.key_algorithm)
    error_message = "key_algorithm must be one of ACM-supported values."
  }
}

variable "validation_record_ttl" {
  description = "TTL cho CNAME validation record. 60s = renew detect nhanh, không ảnh hưởng vì record chỉ ACM dùng."
  type        = number
  default     = 60
}

variable "validation_timeout" {
  description = "Timeout chờ ACM cert ISSUED. DNS-01 cùng account ~3-5 phút bình thường."
  type        = string
  default     = "10m"
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
  description = "Data sensitivity. Public cert → public."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. ACM cert auto-renew bởi AWS → none."
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
