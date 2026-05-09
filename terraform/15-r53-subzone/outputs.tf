output "subzone_id" {
  description = "Hosted Zone ID của sub-zone — dùng cho IRSA policy ChangeResourceRecordSets resource scope"
  value       = aws_route53_zone.subzone.zone_id
}

output "subzone_name" {
  description = "FQDN của sub-zone (no trailing dot) — dùng cho ExternalDNS domainFilter, ACM cert SAN"
  value       = aws_route53_zone.subzone.name
}

output "subzone_arn" {
  description = "ARN của sub-zone — dùng trong IAM policy resource statement"
  value       = aws_route53_zone.subzone.arn
}

output "subzone_name_servers" {
  description = "4 NS server của sub-zone — verify delegation NS record ở apex match"
  value       = aws_route53_zone.subzone.name_servers
}

output "apex_zone_id" {
  description = "Apex zone ID (lookup qua data source) — debug delegation record"
  value       = data.aws_route53_zone.apex.zone_id
}
