locals {
  name_prefix = "${var.project}-${var.env}"

  subzone_id   = data.terraform_remote_state.subzone.outputs.subzone_id
  subzone_name = data.terraform_remote_state.subzone.outputs.subzone_name

  cert_domain = "*.${local.subzone_name}"
  cert_sans   = [local.subzone_name]

  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "acm"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
