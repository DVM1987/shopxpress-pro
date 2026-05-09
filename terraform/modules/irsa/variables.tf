# ============================================================
# Reusable IRSA module — IAM role assumed bởi K8s ServiceAccount
# ============================================================
# Pattern: 1 module = 1 IAM role + N policy attach. Caller pass:
#   - OIDC Provider ARN + URL (từ Sub-comp 5 main)
#   - Namespace + SA name (sub claim trong JWT)
#   - List policy ARN (managed AWS hoặc customer-managed)
# Trust policy được render tự động từ 4 input đó.
# ============================================================

variable "oidc_provider_arn" {
  description = "ARN của IAM OIDC Provider (federated principal trong trust policy)"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL — KHÔNG strip https://, module tự strip cho condition key"
  type        = string

  validation {
    condition     = startswith(var.oidc_provider_url, "https://")
    error_message = "oidc_provider_url phải bắt đầu bằng https:// (raw output từ EKS describe-cluster)."
  }
}

variable "sa_namespace" {
  description = "K8s namespace của ServiceAccount sẽ assume role này"
  type        = string
}

variable "sa_name" {
  description = "K8s ServiceAccount name. Trust policy condition StringEquals sub = system:serviceaccount:<ns>:<name>. Sai 1 chữ = STS reject im lặng."
  type        = string
}

variable "role_name" {
  description = "IAM role name. Convention: <project>-<env>-irsa-<workload> (vd shopxpress-pro-nonprd-irsa-vpc-cni)"
  type        = string

  validation {
    condition     = length(var.role_name) <= 64
    error_message = "IAM role name max 64 ký tự."
  }
}

variable "role_description" {
  description = "IAM role description (audit trail). ASCII+Latin-1 only — không tiếng Việt."
  type        = string
  default     = ""
}

variable "policy_arns" {
  description = "List ARN policy attach vào role. Dùng list để hỗ trợ multi-policy workload (vd LBC cần 1 customer + 1 inline)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tag dán role"
  type        = map(string)
  default     = {}
}
