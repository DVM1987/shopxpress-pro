# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix. ECR repo = <project>-<service> (KHÔNG có env vì ECR shared cross-env)."
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name. Dùng cho tag, KHÔNG cho repo name (ECR shared cross-env nonprd)."
  type        = string
  default     = "nonprd"
}

variable "region" {
  description = "AWS region cho ECR registry (registry per-account per-region)"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Repo settings
# ============================================================

variable "services" {
  description = "Tên service → 1 service = 1 ECR repo. Đặt ở 1 chỗ, đổi list là spawn/remove repo."
  type        = list(string)
  default     = ["gateway", "products", "orders"]
}

variable "image_tag_mutability" {
  description = "IMMUTABLE: tag không đè được (audit trail + rollback an toàn). MUTABLE: dev local."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "encryption_type" {
  description = "AES256 (AWS-owned key, free) hoặc KMS (customer/managed key, audit qua CloudTrail). Lab A++ AES256 đủ."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN khi encryption_type=KMS. Trống = AES256."
  type        = string
  default     = null
}

variable "force_delete" {
  description = "true: terraform destroy xoá repo kể cả còn image (Lab convenience). false: phải empty trước (production safe)."
  type        = bool
  default     = false
}

# ============================================================
# Lifecycle policy — 2 rule pattern
# ============================================================

variable "lifecycle_keep_count" {
  description = "Số image tagged mới nhất giữ lại cho rollback. 10 đủ rollback ~10 lần. Production critical 20-30."
  type        = number
  default     = 10
}

variable "lifecycle_untagged_days" {
  description = "Untagged image > N ngày auto expire (cleanup garbage manifest con multi-arch + push lỗi)."
  type        = number
  default     = 1
}

variable "lifecycle_tag_patterns" {
  description = "Wildcard tag patterns được giữ lại. Match OR — image match BẤT KỲ pattern là apply rule."
  type        = list(string)
  default     = ["dev*", "stg*", "prd*", "v*"]
}

# ============================================================
# Registry-level scanning
# ============================================================

variable "registry_scan_type" {
  description = "BASIC (free, Clair) hoặc ENHANCED (Inspector v2, $0.09/scan)."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "ENHANCED"], var.registry_scan_type)
    error_message = "registry_scan_type must be BASIC or ENHANCED."
  }
}

variable "registry_scan_filter" {
  description = "Wildcard filter repo cần scan. * = mọi repo trong account. shopxpress-pro-* = giới hạn scope."
  type        = string
  default     = "*"
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
  description = "Image artifact có thể chứa cred/config rò → confidential (nâng restricted nếu image production có secret embed)."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "ECR image có thể rebuild từ Git source → none. Compliance giữ image cũ thì dùng lifecycle Archive action thay backup."
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
