# ============================================================
# Helm release — ArgoCD non-HA
# ============================================================
# Chart: argo/argo-cd 9.5.12 (app v3.4.1).
# Mapping verify qua `helm search repo argo/argo-cd --versions` 2026-05-10.
#
# Controller stack 5 pod chính:
#   1. argocd-server          — REST/gRPC + Web UI
#   2. argocd-repo-server     — clone Git, render Helm/Kustomize
#   3. argocd-application-controller (StatefulSet) — reconcile loop diff Git ↔ cluster
#   4. argocd-applicationset-controller — đẻ Application từ template (Sub-comp 0.7.7)
#   5. argocd-redis           — cache render output + live state
#
# values:
#   File `values.yaml` cùng folder, chứa override non-HA + server.insecure: true.
#   `file(path.module/...)` đọc file thẳng (không templating); nếu cần template
#   hóa hostname/cert ARN → đổi sang `templatefile()` (Phase 4 multi-region).
#
# Phase B đã dùng `helm install -f values.yaml` cùng file này, deploy PASS.
# Phase D dùng `helm_release` đọc cùng file, kết quả cluster object identical.
# ============================================================
resource "helm_release" "argocd" {
  name       = local.argocd_release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  namespace        = local.argocd_namespace
  create_namespace = true

  wait    = true
  timeout = var.argocd_helm_timeout_seconds
  atomic  = true

  values = [
    file("${path.module}/values.yaml"),
  ]
}

# ============================================================
# Ingress — IngressGroup share ALB `shopxpress-pro-public`
# ============================================================
# File `argocd-ingress.yaml` cùng folder:
#   - annotation `group.name: shopxpress-pro-public` → LBC gom với Ingress khác
#   - certificate-arn HARDCODE từ Sub-comp 55-acm (cert wildcard ISSUED apse1)
#   - hostname HARDCODE `argocd.shopxpress-pro.do2602.click`
#
# WHY HARDCODE thay vì data.terraform_remote_state.acm.outputs.cert_arn:
#   - Phase B đã chạy file YAML này qua `kubectl apply` PASS → reuse y nguyên
#   - 80-argocd KHÔNG dự kiến deploy account khác (Phase 4 account B
#     dùng cluster cũ, không cài ArgoCD riêng)
#   - Giảm phụ thuộc cross-state, init plan apply nhanh hơn
#
# WHY kubectl_manifest (KHÔNG kubernetes_manifest):
#   Pattern thống nhất với 65-eso (CSS/ES). Ingress không phải CRD nhưng
#   gavinbunney/kubectl validate apply-time, an toàn hơn dirty state edge.
#
# depends_on helm_release để Service `argocd-server` (target backend Ingress)
# tồn tại trước. Nếu không, Ingress tạo nhưng target group rỗng tới khi svc lên.
# ============================================================
resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = file("${path.module}/argocd-ingress.yaml")

  depends_on = [helm_release.argocd]
}
