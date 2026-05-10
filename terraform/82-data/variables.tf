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
# Bitnami PostgreSQL chart
# ============================================================
# Verify version: helm search repo bitnamilegacy/postgresql --versions
# 18.6.4 = chart latest 2026-05-10, app PostgreSQL 18.3.0
variable "postgresql_chart_version" {
  description = "Chart version bitnamilegacy/postgresql. Pin = reproducible."
  type        = string
  default     = "18.6.4"
}

variable "postgresql_image_repository" {
  description = "Image override Bitnami legacy migration 2025-08. Bitnami chart default trỏ docker.io/bitnami/* (paid). Phải override sang bitnamilegacy/* (free, frozen)."
  type        = string
  default     = "bitnamilegacy/postgresql"
}

variable "postgresql_image_tag" {
  description = "Image tag pin reproducible. Chart default `latest` = anti-pattern (drift mỗi lần pull). Pin tag stable, bump khi cần upgrade có chủ đích."
  type        = string
  default     = "17.6.0-debian-12-r4"
}

variable "data_namespace" {
  description = "K8s namespace cho data layer StatefulSet. Tách khỏi NS app (dev/stg/prd) để RBAC + NetworkPolicy quản lý riêng."
  type        = string
  default     = "shopxpress-data"
}

variable "storage_class_name" {
  description = "StorageClass name. gp3 = next-gen EBS volume type, IOPS+throughput tunable, rẻ hơn gp2 ~20%."
  type        = string
  default     = "gp3"
}

variable "helm_timeout_seconds" {
  description = "Timeout chờ chart deploy (StatefulSet pod Ready, PVC Bound)."
  type        = number
  default     = 600
}

# ============================================================
# AWS Secrets Manager
# ============================================================
# `shopxpress-pro/<env>/<service>-db` — match prefix ESO policy
# scope `arn:aws:secretsmanager:*:*:secret:shopxpress-pro/*`.
variable "secret_name_prefix" {
  description = "Path prefix tên secret Secrets Manager. Phải match ESO policy 65-eso scope shopxpress-pro/*."
  type        = string
  default     = "shopxpress-pro"
}

variable "secret_recovery_window_days" {
  description = "Recovery window khi destroy. 0 = force-delete ngay (lab, không bill $0.40/30d). Production để 7-30."
  type        = number
  default     = 0
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
  description = "Data sensitivity. Postgres production data → confidential."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy. Lab nonprd dùng `none` — production phải đặt daily/critical (Velero hoặc snapshot EBS DLM)."
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
