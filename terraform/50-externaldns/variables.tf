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
# Helm release config
# ============================================================

variable "externaldns_chart_version" {
  description = "Chart version external-dns/external-dns. Mapping chart 1.21.x → app v0.21.x. Pin = reproducible."
  type        = string
  default     = "1.21.1"
}

variable "externaldns_replica_count" {
  description = "Số replica controller. 1 đủ cho 1 cluster (chỉ 1 leader có ý nghĩa, multi-replica chỉ giảm RTO failover ~15s, không tăng throughput vì leader-election)."
  type        = number
  default     = 1
}

variable "externaldns_helm_timeout_seconds" {
  description = "Timeout chờ chart deploy thành công. 600s đủ cho cluster lab."
  type        = number
  default     = 600
}

variable "externaldns_txt_owner_id" {
  description = "Marker registry trong TXT record để identify cluster nào own DNS record. Tránh conflict khi multi-cluster cùng touch 1 zone. Pattern: <project>-<env>"
  type        = string
  default     = "shopxpress-pro-nonprd"
}

variable "externaldns_policy" {
  description = "Sync policy: 'sync' = tạo+update+DELETE record (production), 'upsert-only' = tạo+update KHÔNG delete (an toàn hơn lúc test). Default sync vì cluster lab cần cleanup tự động khi xoá Ingress."
  type        = string
  default     = "sync"

  validation {
    condition     = contains(["sync", "upsert-only", "create-only"], var.externaldns_policy)
    error_message = "externaldns_policy must be one of: sync, upsert-only, create-only."
  }
}

variable "externaldns_interval" {
  description = "Reconciliation interval. Default chart=1m. Dev tăng tốc để debug nhanh, prod 5m+ để giảm R53 API call (cost + throttle)."
  type        = string
  default     = "1m"
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
