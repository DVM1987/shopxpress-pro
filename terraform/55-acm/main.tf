# ============================================================
# ACM Public Certificate — wildcard + apex SAN
# ============================================================
# Cert phục vụ ALB listener 443 cho mọi service Lab A++:
#   - CN  : *.shopxpress-pro.do2602.click  (wildcard 1 level)
#   - SAN : shopxpress-pro.do2602.click    (apex sub-zone, wildcard không cover)
#
# Wildcard quirk: `*.X` cover được argocd/grafana/jenkins.X (1 level), KHÔNG
# cover apex `X` và KHÔNG cover multi-level `a.b.X` → SAN apex bắt buộc, multi
# level cần wildcard riêng `*.b.X` (chưa cần ở Lab A++).
#
# `create_before_destroy = true` để khi rotate cert (đổi key_algorithm,
# thay SAN), TF tạo cert mới TRƯỚC khi destroy cert cũ → ALB không bị mất
# listener cert giữa chừng.
resource "aws_acm_certificate" "wildcard" {
  domain_name               = local.cert_domain
  subject_alternative_names = local.cert_sans
  validation_method         = "DNS"
  key_algorithm             = var.key_algorithm

  tags = {
    Name = "${local.name_prefix}-wildcard-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# DNS validation records — CNAME trong sub-zone
# ============================================================
# ACM dedup: wildcard `*.X` + apex `X` cùng base domain → ACM gom thành
# CHỈ 1 CNAME validation record (cả 2 SAN trỏ chung CNAME). Loop for_each
# qua `domain_validation_options` set, distinct theo `domain_name`, kết quả
# 1 element duy nhất — KHÔNG tạo 2 record trùng value.
#
# `allow_overwrite = true` để TF idempotent re-apply (cert re-issue cùng
# CNAME thì record không conflict).
resource "aws_route53_record" "validation" {
  for_each = {
    for opt in aws_acm_certificate.wildcard.domain_validation_options :
    opt.domain_name => {
      name   = opt.resource_record_name
      type   = opt.resource_record_type
      record = opt.resource_record_value
    }
  }

  zone_id         = local.subzone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = var.validation_record_ttl
  allow_overwrite = true
}

# ============================================================
# Certificate validation gate
# ============================================================
# Block TF apply tới khi ACM detect CNAME đã propagate và status flip
# PENDING_VALIDATION → ISSUED. Sub-comp downstream (Ingress) chỉ nên
# consume cert ARN sau khi resource này hoàn tất.
#
# DNS-01 cùng account: ~3-5 phút end-to-end (CNAME propagate ~30s + ACM
# poll detect ~2-3 phút).
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]

  timeouts {
    create = var.validation_timeout
  }
}
