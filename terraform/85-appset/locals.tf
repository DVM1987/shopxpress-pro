locals {
  name_prefix  = "${var.project}-${var.env}"
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_id

  # Tag enterprise tier — đồng bộ pattern 80-argocd, biến hoá Component
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "argocd-appset"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
