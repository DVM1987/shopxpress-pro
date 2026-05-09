output "ingress_host" {
  description = "FQDN smoke test (qua ExternalDNS sync về R53)"
  value       = local.ingress_host
}

output "alb_dns" {
  description = "ALB DNS từ LBC sinh — sanity check resolve trùng với A record sau sync"
  value       = try(kubernetes_ingress_v1.smoke.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "cert_arn_used" {
  description = "Cert ARN gắn vào ALB listener 443"
  value       = local.cert_arn
}

output "smoke_url_https" {
  description = "URL HTTPS để curl verify"
  value       = "https://${local.ingress_host}"
}

output "smoke_url_http" {
  description = "URL HTTP để verify 301 redirect"
  value       = "http://${local.ingress_host}"
}
