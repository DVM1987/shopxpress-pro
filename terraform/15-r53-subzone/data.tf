# Apex zone (do2602.click) đã tồn tại từ trước, lookup qua name để KHÔNG
# hardcode zone_id — nếu apex re-create thì TF tự bắt zone_id mới.
data "aws_route53_zone" "apex" {
  name         = var.apex_zone_name
  private_zone = false
}
