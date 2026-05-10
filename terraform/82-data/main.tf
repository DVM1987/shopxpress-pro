# ============================================================
# Namespace shopxpress-data — riêng cho StatefulSet PostgreSQL
# ============================================================
# Tách khỏi NS app (dev/stg/prd) để:
#   1. RBAC: dev team có quyền edit NS app, KHÔNG đụng được data layer
#   2. NetworkPolicy: chỉ allow traffic từ NS app → data NS port 5432
#   3. Resource quota riêng cho stateful workload (memory + storage cap)
#   4. Cleanup: destroy data layer = delete NS, KHÔNG kéo theo app
#
# Pod-Security Standard `baseline` cho NS data — cho phép Bitnami chart
# (cần writable filesystem cho /bitnami/postgresql/data, KHÔNG chạy được
# `restricted` profile).
# ============================================================
resource "kubernetes_namespace_v1" "data" {
  metadata {
    name = var.data_namespace

    labels = {
      "app.kubernetes.io/name"               = var.data_namespace
      "app.kubernetes.io/managed-by"         = "terraform"
      "pod-security.kubernetes.io/enforce"   = "baseline"
      "pod-security.kubernetes.io/audit"     = "baseline"
      "pod-security.kubernetes.io/warn"      = "baseline"
    }
  }
}

# ============================================================
# StorageClass gp3 — default class cluster-wide
# ============================================================
# Cluster đang chạy SC `gp2` legacy (in-tree provisioner kubernetes.io/aws-ebs).
# Tạo gp3 mới với CSI provisioner ebs.csi.aws.com (đã ACTIVE Sub-comp 4):
#
# Tại sao gp3 thay gp2:
#   - Performance: gp3 tách IOPS/throughput khỏi size (gp2 ràng buộc 3 IOPS/GB)
#   - Cost: gp3 rẻ hơn gp2 ~20% mỗi GB-month
#   - Tuning: iops 3000 + throughput 125 MiB/s = baseline đủ nhiều workload
#
# `is-default-class=true`: PVC không khai storageClassName → K8s assign SC này.
# Nếu cluster đã có default SC khác → patch gp2 bỏ default annotation:
#   kubectl annotate sc gp2 storageclass.kubernetes.io/is-default-class-
#
# `WaitForFirstConsumer`: BẮT BUỘC cho cluster multi-AZ — đợi pod schedule
# rồi mới đẻ EBS đúng AZ. `Immediate` (mặc định in-tree gp2) sẽ đẻ EBS random
# AZ → pod schedule AZ khác = không mount được.
#
# `allowVolumeExpansion=true`: PVC.spec.resources.requests.storage tăng = EBS
# online resize không downtime (gp3 hỗ trợ).
#
# `encrypted=true`: dùng KMS key alias/aws/ebs (AWS managed). Production cần
# customer-managed KMS thì set `kmsKeyId` parameter.
# ============================================================
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = var.storage_class_name

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
    # Baseline performance — tunable per workload nếu cần
    iops       = "3000"
    throughput = "125"
  }
}

# ============================================================
# Random password — postgres superuser (per DB)
# ============================================================
# Mỗi DB cần 2 password:
#   1. postgres (superuser) — dùng cho admin task: backup, alter role
#   2. <app_username> — app dùng connect, KHÔNG có quyền DROP/TRUNCATE
#
# Sinh trong RAM lúc apply, ghi thẳng vào Secrets Manager. State file (S3 +
# encrypted) lưu hash, KHÔNG plaintext khi đọc qua `terraform show`.
#
# `special = false`: ký tự đặc biệt có thể gãy DSN URL khi không URL-encode.
# Production: special = true + dùng url-encode bên consumer side.
# ============================================================
resource "random_password" "postgres" {
  for_each = local.databases

  length  = 24
  special = false
  upper   = true
  lower   = true
  numeric = true

  keepers = {
    db_key = each.key
  }
}

resource "random_password" "app" {
  for_each = local.databases

  length  = 24
  special = false
  upper   = true
  lower   = true
  numeric = true

  keepers = {
    db_key = each.key
  }
}

# ============================================================
# AWS Secrets Manager — secret metadata + version JSON
# ============================================================
# Tách 2 resource (metadata vs value): pattern senior 65-eso đã dùng.
#   - aws_secretsmanager_secret = name + KMS + tags (rotation Lambda gắn vào đây)
#   - aws_secretsmanager_secret_version = secret_string JSON
#
# Secret name: `shopxpress-pro/dev/products-db` — phải có prefix
# `shopxpress-pro/` để match ESO IAM policy 65-eso scope.
#
# JSON format chuẩn `kind=postgresql` AWS RDS connector schema (compatible
# với rotation Lambda chuẩn):
#   {
#     "engine": "postgres",
#     "host": "products-db.shopxpress-data.svc.cluster.local",
#     "port": 5432,
#     "database": "products",
#     "username": "products_app",
#     "password": "<random>",
#     "postgres_password": "<random superuser>"
#   }
#
# ExternalSecret CRD ở repo deploy sẽ dùng template build DSN từ JSON này.
# ============================================================
resource "aws_secretsmanager_secret" "db" {
  for_each = local.databases

  name                    = "${var.secret_name_prefix}/${var.env}/${each.key}-db"
  description             = "PostgreSQL credentials for ${each.key} service - synced by ESO"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name      = "${var.secret_name_prefix}/${var.env}/${each.key}-db"
    Component = "secret-${each.key}-db"
    Database  = each.value.database
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  for_each = local.databases

  secret_id = aws_secretsmanager_secret.db[each.key].id

  # DATABASE_URL precomputed: tránh ExternalSecret template phức tạp,
  # consumer (app pod env) lấy thẳng 1 key. Format pgx-compatible:
  #   postgres://<user>:<pass>@<host>:<port>/<db>?sslmode=disable
  # `sslmode=disable` cho lab in-cluster; production = require + verify-ca
  # với cert PG sign bởi K8s CA hoặc bring-your-own.
  secret_string = jsonencode({
    DATABASE_URL = "postgres://${each.value.app_username}:${random_password.app[each.key].result}@${each.key}-db.${var.data_namespace}.svc.cluster.local:5432/${each.value.database}?sslmode=disable"

    # Raw fields giữ lại — debug, rotation Lambda tương lai có thể consume
    engine            = "postgres"
    host              = "${each.key}-db.${var.data_namespace}.svc.cluster.local"
    port              = 5432
    database          = each.value.database
    username          = each.value.app_username
    password          = random_password.app[each.key].result
    postgres_password = random_password.postgres[each.key].result
  })
}

# ============================================================
# Helm release — Bitnami PostgreSQL StatefulSet (per DB)
# ============================================================
# Chart bitnamilegacy/postgresql 18.6.4 = app PostgreSQL 18.3.0.
# Repo `bitnamilegacy` (Broadcom hosted, free, frozen 2025-08).
# KHÔNG dùng `bitnami` repo paid hoặc charts.bitnami.com (image deprecated).
#
# Architecture `standalone`: 1 primary, KHÔNG replication.
#   - Lab nonprd: đủ cho demo + interview STAR
#   - Production: chuyển `replication` (1 primary + N read replica), thêm
#     PgBouncer connection pooling, hoặc move sang RDS Multi-AZ
#
# fullnameOverride: ép tên Service = `<key>-db` thay vì
# `<release>-postgresql` mặc định. Lý do: DSN gọn:
#   postgres://products_app:pass@products-db.shopxpress-data.svc.cluster.local:5432/products
#
# image.repository: override `bitnamilegacy/postgresql` (default chart trỏ
# `bitnami/postgresql` paid). MIGRATION 2025-08, mọi Bitnami chart phải override.
#
# auth.* values: TF set password vào chart, đồng thời ghi cùng password đó
# vào Secrets Manager → single source of truth = TF state.
#
# primary.persistence.* : EBS gp3 8Gi PVC qua SC `gp3` (vừa tạo trên).
# StatefulSet volumeClaimTemplates auto-tạo PVC `data-<release>-postgresql-0`.
# ============================================================
resource "helm_release" "postgresql" {
  for_each = local.databases

  name       = "${each.key}-db"
  repository = "https://repo.broadcom.com/bitnami-files/"
  chart      = "postgresql"
  version    = var.postgresql_chart_version

  namespace        = kubernetes_namespace_v1.data.metadata[0].name
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = var.helm_timeout_seconds

  set = [
    # ----------- Image override Bitnami legacy migration -----------
    {
      name  = "image.repository"
      value = var.postgresql_image_repository
    },
    {
      name  = "image.registry"
      value = "docker.io"
    },
    {
      name  = "image.tag"
      value = var.postgresql_image_tag
    },

    # ----------- Topology -----------
    {
      name  = "architecture"
      value = "standalone"
    },
    {
      name  = "fullnameOverride"
      value = "${each.key}-db"
    },

    # ----------- Auth (4 password Bitnami chart cần) -----------
    {
      name  = "auth.database"
      value = each.value.database
    },
    {
      name  = "auth.username"
      value = each.value.app_username
    },

    # ----------- Persistence — EBS gp3 PVC -----------
    {
      name  = "primary.persistence.enabled"
      value = "true"
    },
    {
      name  = "primary.persistence.storageClass"
      value = var.storage_class_name
    },
    {
      name  = "primary.persistence.size"
      value = each.value.storage_size
    },

    # ----------- Resource limits (sane defaults) -----------
    {
      name  = "primary.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "primary.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "primary.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "primary.resources.limits.memory"
      value = "512Mi"
    },

    # ----------- Service type ClusterIP — KHÔNG expose ngoài cluster -----------
    {
      name  = "primary.service.type"
      value = "ClusterIP"
    },
  ]

  # ----------- Password (sensitive) — set_sensitive để KHÔNG log plaintext -----------
  set_sensitive = [
    {
      name  = "auth.password"
      value = random_password.app[each.key].result
    },
    {
      name  = "auth.postgresPassword"
      value = random_password.postgres[each.key].result
    },
  ]

  # SC + namespace phải sẵn trước khi chart deploy (PVC bind).
  depends_on = [
    kubernetes_storage_class_v1.gp3,
    kubernetes_namespace_v1.data,
  ]
}
