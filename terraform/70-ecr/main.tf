# ============================================================
# 1. ECR repositories — for_each per service
# ============================================================
# Tạo 3 repo Immutable + AES-256. Tag default đính qua provider.
# force_delete = false production: muốn destroy phải empty repo trước
# (operator phải xoá image — buộc người ta nghĩ kỹ trước khi xoá).
resource "aws_ecr_repository" "this" {
  for_each = local.repo_names

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  # WHY KHÔNG dùng image_scanning_configuration block:
  # Block này set scan-on-push REPO-LEVEL, đã DEPRECATED khi có
  # registry-level rule (xem aws_ecr_registry_scanning_configuration
  # bên dưới). Registry-level rule * override repo-level.

  tags = {
    Service = each.key
    Name    = each.value
  }
}

# ============================================================
# 2. Lifecycle policy — for_each per repo
# ============================================================
# 2 rule: keep 10 tagged + expire untagged > 1 day. JSON dùng chung
# render trong locals (KHÔNG hardcode trong từng resource).
# ECR đánh giá lifecycle BATCH DAILY, không real-time → push image 11
# thì image 1 không xoá ngay, tới ngày sau mới chạy.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy     = local.lifecycle_policy
}

# ============================================================
# 3. Registry-level scanning rule — singleton account-level
# ============================================================
# Setting này áp TOÀN ACCOUNT, không scope theo repo. Filter `*` =
# mọi repo (kể cả future repo Lab khác trong account này) auto scan.
# WHY managed ở folder 70-ecr: chốt với user — 1 stack quản ECR.
# Trade-off: future Lab tạo repo cùng account sẽ scan cả → expected.
resource "aws_ecr_registry_scanning_configuration" "this" {
  scan_type = var.registry_scan_type

  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = var.registry_scan_filter
      filter_type = "WILDCARD"
    }
  }
}
