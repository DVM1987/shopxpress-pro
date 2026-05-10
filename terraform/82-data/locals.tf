locals {
  name_prefix = "${var.project}-${var.env}"

  # ============================================================
  # Databases map — key driver cho mọi for_each
  # ============================================================
  # Mỗi entry = 1 PostgreSQL StatefulSet độc lập (database-per-service
  # antipattern shared DB). Service `gateway` = BFF stateless KHÔNG có DB.
  #
  # Field:
  #   - database     = tên database default chart tạo lúc init
  #   - app_username = role app dùng (KHÔNG phải postgres superuser)
  #   - storage_size = EBS gp3 PVC. 8Gi đủ lab, production tăng theo nhu cầu
  #     + bật autoresize qua resizer sidecar (allowVolumeExpansion=true SC)
  # ============================================================
  databases = {
    products = {
      database     = "products"
      app_username = "products_app"
      storage_size = "8Gi"
    }
    orders = {
      database     = "orders"
      app_username = "orders_app"
      storage_size = "8Gi"
    }
  }

  # 10 tag chuẩn enterprise — same pattern các Sub-comp khác
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "data-layer"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }
}
