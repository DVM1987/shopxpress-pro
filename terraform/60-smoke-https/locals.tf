locals {
  name_prefix = "${var.project}-${var.env}"

  app_name      = "nginx-smoke-https"
  app_namespace = "default"
  app_image     = "public.ecr.aws/nginx/nginx:1.27"
  app_port      = 80

  ingress_host = "smoke.${data.terraform_remote_state.subzone.outputs.subzone_name}"
  cert_arn     = data.terraform_remote_state.acm.outputs.cert_arn

  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "smoke-https"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }

  app_labels = {
    "app.kubernetes.io/name"       = local.app_name
    "app.kubernetes.io/component"  = "smoke"
    "app.kubernetes.io/part-of"    = var.project
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
