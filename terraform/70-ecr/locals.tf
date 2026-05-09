locals {
  # ECR repo name pattern: <project>-<service>. KHÔNG nhúng env vì ECR shared cross-env.
  # Đổi var.services là spawn/remove repo trong 1 lần apply.
  repo_names = { for s in var.services : s => "${var.project}-${s}" }

  # Lifecycle policy JSON — render 1 lần dùng cho mọi repo (for_each).
  # Match khớp 100% policy đã verify ở Phase B Console UI.
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.lifecycle_keep_count} tagged images per env for rollback"
        selection = {
          tagStatus       = "tagged"
          tagPatternList  = var.lifecycle_tag_patterns
          countType       = "imageCountMoreThan"
          countNumber     = var.lifecycle_keep_count
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than ${var.lifecycle_untagged_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.lifecycle_untagged_days
        }
        action = { type = "expire" }
      }
    ]
  })

  # Tag enterprise tier — biến hoá Component = "ecr-registry"
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "ecr-registry"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
