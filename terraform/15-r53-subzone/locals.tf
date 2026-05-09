locals {
  name_prefix = "${var.project}-${var.env}"

  # 10 tag enterprise tier — same pattern as VPC/EKS/MNG
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "r53-subzone"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
