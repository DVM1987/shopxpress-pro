locals {
  # Naming prefix dùng cho IAM Role / KMS alias / Log Group
  name_prefix = var.cluster_name

  # 10 tag chuẩn enterprise — Component default = "eks" (sub-resource override khi cần)
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "eks"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
