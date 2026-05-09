# ============================================================
# Public sub-zone — hosted zone con cho services Lab A++
# ============================================================
# Pattern enterprise: tách sub-zone per project/environment để:
#   - Cô lập blast radius (sửa record dev không đụng record apex)
#   - Least-privilege IAM (ExternalDNS/cert-manager scope sub-zone duy nhất)
#   - Audit log riêng (CloudTrail filter theo zone_id sub-zone)
#   - Cleanup an toàn (xoá sub-zone không đụng apex)
resource "aws_route53_zone" "subzone" {
  name    = var.subzone_name
  comment = "Sub-zone for ${var.project} ${var.env} services. Delegated from ${var.apex_zone_name}."

  tags = {
    Name = var.subzone_name
  }
}

# ============================================================
# Delegation NS record ở apex zone
# ============================================================
# Khi tạo Hosted Zone mới, R53 assign 4 NS server (delegation set).
# Để Internet resolver biết "ai serve sub-zone này", phải tạo NS record
# ở apex zone trỏ vào 4 NS server đó.
# RFC 1912 recommend TTL >= 24h cho NS record (delegation hiếm thay đổi).
resource "aws_route53_record" "delegation" {
  zone_id = data.aws_route53_zone.apex.zone_id
  name    = var.subzone_name
  type    = "NS"
  ttl     = var.delegation_ttl
  records = aws_route53_zone.subzone.name_servers
}
