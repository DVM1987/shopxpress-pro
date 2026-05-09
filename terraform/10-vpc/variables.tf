variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name (dev/stg/prd). Single VPC, multi-env via k8s namespace"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, /16 gives 65k IPs"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability Zones used for the 3-AZ design"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnets, one /24 per AZ (ALB + NAT)"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private app subnets, one /19 per AZ (EKS workers + pods, Prefix Delegation friendly)"
  type        = list(string)
  default     = ["10.20.32.0/19", "10.20.64.0/19", "10.20.96.0/19"]
}

variable "private_data_subnet_cidrs" {
  description = "Private data subnets, one /24 per AZ (RDS / Redis / Vault)"
  type        = list(string)
  default     = ["10.20.128.0/24", "10.20.129.0/24", "10.20.130.0/24"]
}

# ============================================================
# Tagging variables (governance, finops, audit)
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
  description = "Data sensitivity: public/internal/confidential/restricted"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy: none/daily/weekly/critical"
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
