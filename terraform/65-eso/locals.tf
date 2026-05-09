locals {
  name_prefix  = "${var.project}-${var.env}"
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_id

  # ESO controller cài qua chart, NS chart-managed
  eso_namespace      = "external-secrets"
  eso_sa_name        = "external-secrets"
  eso_release_name   = "external-secrets"
  eso_role_name      = "${local.name_prefix}-irsa-eso"
  eso_policy_name    = "${local.name_prefix}-eso-secretsmanager-read"

  # Tag enterprise tier — same pattern as ExternalDNS, biến hoá Component
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "eso-controller"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
