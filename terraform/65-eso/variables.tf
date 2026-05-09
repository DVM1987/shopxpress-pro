# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name. Cluster scope = nonprd (dev + stg shared)."
  type        = string
  default     = "nonprd"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Helm release config — ESO chart
# ============================================================

variable "eso_chart_version" {
  description = "Chart version external-secrets/external-secrets. Mapping chart 2.4.x → app v2.4.x. Pin = reproducible."
  type        = string
  default     = "2.4.1"
}

variable "eso_helm_timeout_seconds" {
  description = "Timeout chờ chart deploy thành công (ESO tạo 3 deployment + 23 CRD, nặng hơn ExternalDNS). 600s đủ."
  type        = number
  default     = 600
}

variable "eso_replica_count" {
  description = "Số replica controller ESO. 1 đủ cho lab; production HA dùng 2-3 (controller có leader-election Lease)."
  type        = number
  default     = 1
}

# ============================================================
# Demo secret + ExternalSecret config
# ============================================================

variable "demo_secret_name" {
  description = "Tên (path-style) secret demo trong AWS Secrets Manager. Pattern <project>/<env>/<purpose> để IAM policy wildcard scope theo env."
  type        = string
  default     = "shopxpress-pro/dev/demo-eso"
}

variable "demo_secret_username" {
  description = "Username bên trong JSON secret (non-sensitive)"
  type        = string
  default     = "demo"
}

variable "demo_secret_password_length" {
  description = "Độ dài password random sinh tự động. 32 ký tự đủ entropy ~190 bit."
  type        = number
  default     = 32
}

variable "eso_refresh_interval" {
  description = "ExternalSecret refreshInterval. 1m dev (debug nhanh), prod 1h+ (giảm SM API call $0.05/10k). Tính: 1 secret refresh 1m = 43200 call/tháng = $0.22; refresh 1h = 720 call/tháng = $0.0036."
  type        = string
  default     = "1m"
}

variable "app_namespace" {
  description = "Namespace K8s nơi ExternalSecret + K8s Secret đẻ ra. Dev pattern: tách riêng 1 NS demo cho secret-sync, prod: từng app NS có ES riêng."
  type        = string
  default     = "app-demo"
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
  description = "Data sensitivity. ESO touch credential workload → restricted (cao hơn confidential)."
  type        = string
  default     = "restricted"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. Controller stateless → none. SM secret AWS managed có versioning built-in."
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
