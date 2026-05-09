# ============================================================
# Core
# ============================================================

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shopxpress-pro"
}

variable "env" {
  description = "Environment name (dev/stg/prd) — tag value, not part of MNG name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ============================================================
# Node group config
# ============================================================

variable "node_group_name" {
  description = "MNG name. Immutable. Đổi tên = tạo MNG mới + drain MNG cũ."
  type        = string
  default     = "default"
}

variable "instance_types" {
  description = "EC2 instance types cho MNG. List để future-proof spot mixed-fleet (hiện chỉ 1 type)."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "ON_DEMAND hoặc SPOT. ON_DEMAND cho dev workload nhỏ, SPOT khi đủ mass."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type phải là ON_DEMAND hoặc SPOT."
  }
}

variable "ami_type" {
  description = "AMI family. AL2023_x86_64_STANDARD = Amazon Linux 2023 amd64 (current standard, AL2 EOL 2026-11)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "disk_size_gb" {
  description = "Root EBS volume size GB. 50GB = đủ cho image cache + log + buffer (default MNG = 20GB chật cho prod image)."
  type        = number
  default     = 50
}

variable "min_size" {
  description = "ASG min size — floor cho self-healing"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "ASG max size — ceiling cho HPA + Cluster Autoscaler. 6 = headroom 2x"
  type        = number
  default     = 6
}

variable "desired_size" {
  description = "ASG desired size lúc tạo. SAU đó ignore_changes vì Karpenter/HPA quản lý."
  type        = number
  default     = 3
}

variable "max_pods" {
  description = "kubelet maxPods override. Prefix Delegation enable max=110 thay vì 17 (t3.medium default ENI math)."
  type        = number
  default     = 110
}

variable "node_labels" {
  description = "K8s node labels — cho nodeSelector/affinity. Prefix Delegation chưa kick in ở MNG vì Add-on vpc-cni Sub-comp 4 mới ENABLE_PREFIX_DELEGATION=true."
  type        = map(string)
  default = {
    role     = "general"
    capacity = "on-demand"
  }
}

# ============================================================
# Tagging — governance / finops / audit (giống Sub-comp 1+2)
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
  description = "Data sensitivity: public/internal/confidential/restricted. Worker node chạy pod confidential → confidential."
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "backup_policy" {
  description = "Backup policy: none/daily/weekly/critical. MNG node ephemeral (replace = data mất) → none. Workload data đi PVC riêng."
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
