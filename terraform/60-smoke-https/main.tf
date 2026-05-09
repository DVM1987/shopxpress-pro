# ============================================================
# Smoke Deployment nginx — 1 replica, public ECR image (skip Docker Hub
# rate limit), distroless KHÔNG cần vì smoke test pure HTTP.
# ============================================================
resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = local.app_name
    namespace = local.app_namespace
    labels    = local.app_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = local.app_name
      }
    }

    template {
      metadata {
        labels = local.app_labels
      }

      spec {
        container {
          name  = "nginx"
          image = local.app_image

          port {
            name           = "http"
            container_port = local.app_port
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "16Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# ============================================================
# Service ClusterIP — ALB target-type=ip route trực tiếp pod IP
# ============================================================
# LBC mode `ip` (đã set ở Sub-comp 6) bypass Service ClusterIP qua endpoint
# slice → vẫn cần Service làm "selector + port mapping" contract, nhưng
# traffic không proxy qua kube-proxy iptables.
resource "kubernetes_service_v1" "nginx" {
  metadata {
    name      = local.app_name
    namespace = local.app_namespace
    labels    = local.app_labels
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = local.app_name
    }

    port {
      name        = "http"
      port        = local.app_port
      target_port = "http"
      protocol    = "TCP"
    }
  }
}

# ============================================================
# Ingress class=alb — HTTPS listener 443 + HTTP→HTTPS 301 redirect
# ============================================================
# 8 annotation chốt:
#   - scheme=internet-facing      → ALB public (subnet kubernetes.io/role/elb)
#   - target-type=ip              → route trực tiếp pod IP (cần Prefix Delegation)
#   - load-balancer-name          → tên cố định (idempotent, không random)
#   - listen-ports HTTP+HTTPS     → ALB mở 2 listener
#   - certificate-arn             → cert ACM gắn listener 443
#   - ssl-redirect=443            → annotation đặc biệt: LBC tự convert listener 80
#                                   thành action `redirect` 301 → 443 (KHÔNG cần
#                                   khai redirect rule riêng)
#   - ssl-policy                  → TLS policy ELBSecurityPolicy-TLS13-1-2-2021-06
#                                   (TLS 1.2/1.3 only, A+ rating SSLLabs)
#   - external-dns hostname       → ExternalDNS đọc annotation này (sources=ingress
#                                   ở Sub-comp 7c) tạo R53 alias A
resource "kubernetes_ingress_v1" "smoke" {
  metadata {
    name      = local.app_name
    namespace = local.app_namespace
    labels    = local.app_labels

    annotations = {
      "alb.ingress.kubernetes.io/scheme"                  = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"             = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name"      = "${local.name_prefix}-smoke-alb"
      "alb.ingress.kubernetes.io/listen-ports"            = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/certificate-arn"         = local.cert_arn
      "alb.ingress.kubernetes.io/ssl-redirect"            = "443"
      "alb.ingress.kubernetes.io/ssl-policy"              = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "external-dns.alpha.kubernetes.io/hostname"         = local.ingress_host
      "alb.ingress.kubernetes.io/healthcheck-path"        = "/"
      "alb.ingress.kubernetes.io/healthcheck-protocol"    = "HTTP"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = local.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.nginx.metadata[0].name
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  # Wait LBC reconcile xong sinh ALB + register target + healthy trước khi
  # output trả ALB DNS. timeout=5m phòng ALB provision chậm.
  wait_for_load_balancer = true

  timeouts {
    create = "5m"
    delete = "5m"
  }
}
