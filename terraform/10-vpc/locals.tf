locals {
  # Naming convention: <project>-<env>-<resource>[-<az_suffix>]
  # Lowercase + dash, DNS-1123 compliant
  name_prefix = "${var.project}-${var.env}"

  # AZ suffix shortener: ap-southeast-1a → 1a (dùng trong tên subnet/RT)
  az_suffix = [for az in var.azs : substr(az, -2, 2)]

  # Common tags áp lên MỌI resource qua provider default_tags.
  # 10 tag enterprise tier (5 mandatory + 5 governance/finops/audit):
  #   - Project / Environment / Component / ManagedBy / Owner   (mandatory ops)
  #   - CostCenter / Repo                                       (FinOps + traceability)
  #   - DataClassification / BackupPolicy                       (compliance/DR)
  #   - CreatedBy                                               (audit trail)
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "vpc"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
