variable "project" {
  description = "Project name prefix, used in resource naming"
  type        = string
  default     = "shopxpress-pro"
}

variable "region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "account_id" {
  description = "AWS account ID, used to make S3 bucket name globally unique"
  type        = string
}
