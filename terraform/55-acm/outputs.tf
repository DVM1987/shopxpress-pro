output "cert_arn" {
  description = "ARN của cert wildcard — wire vào Ingress annotation alb.ingress.kubernetes.io/certificate-arn"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "cert_domain" {
  description = "CN của cert (wildcard)"
  value       = aws_acm_certificate.wildcard.domain_name
}

output "cert_sans" {
  description = "Subject Alternative Names — list domain cert cover"
  value       = aws_acm_certificate.wildcard.subject_alternative_names
}

output "cert_status" {
  description = "Status cert sau validation (expect ISSUED)"
  value       = aws_acm_certificate.wildcard.status
}

output "cert_not_after" {
  description = "Cert expiry — auto-renew 45 ngày trước nếu CNAME validation còn"
  value       = aws_acm_certificate.wildcard.not_after
}

output "validation_record_fqdns" {
  description = "FQDN của CNAME validation record(s) — debug nếu validation stuck PENDING"
  value       = [for r in aws_route53_record.validation : r.fqdn]
}
