# ============================================================
# 3 namespace workload — dev / stg / prd
# ============================================================
# Tách khỏi namespace argocd để:
#   - RBAC khác nhau: dev/stg cho dev team, prd cho devops + cron CD
#   - Resource quota khác nhau (dev nhỏ, prd full)
#   - Network policy có thể siết per-env (Sub-comp sau)
#
# pod-security.kubernetes.io/enforce=restricted: bật Pod Security Admission
# (PSA) restricted profile — chặn pod chạy root, không cho hostPath, capability
# add. Match với hardened security context trong chart Helm (Sub-comp 0.7.6).
#
# WHY kubectl_manifest thay vì kubernetes_namespace_v1:
#   Provider thống nhất 1 thằng kubectl cho mọi YAML, bớt 1 phụ thuộc provider
#   `hashicorp/kubernetes`. Plain Namespace kind không cần CRD waiting.
# ============================================================
resource "kubectl_manifest" "workload_namespace" {
  for_each = toset(["dev", "stg", "prd"])

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${each.key}
      labels:
        name: ${each.key}
        environment: ${each.key}
        managed-by: argocd
        pod-security.kubernetes.io/enforce: restricted
        pod-security.kubernetes.io/enforce-version: latest
  YAML
}

# ============================================================
# AppProject — ranh giới quyền cho 9 Application
# ============================================================
# Mặc định Application thuộc project `default` (quyền rộng: mọi cluster, mọi
# namespace, mọi repo). Production KHÔNG dùng.
#
# AppProject `shopxpress-pro` whitelist:
#   - sourceRepos: chỉ cho pull từ repo manifest deploy
#   - destinations: chỉ cho deploy vào dev/stg/prd ở cluster local
#   - clusterResourceWhitelist: cho phép kind cluster-scoped (Namespace,
#     ClusterRole...) — Helm chart không tạo cluster-scoped, để '*' chấp nhận
#     ExternalSecret CRD scope cluster (CSS) nếu phát sinh
#   - namespaceResourceWhitelist: '*' để chart Helm tạo Deployment, Service,
#     Ingress, ServiceAccount, ExternalSecret
#
# WHY tách AppProject riêng (không dùng default):
#   - Bot/dev đẩy commit vào repo lạ (vd shopxpress-pro-deploy-fork) → ArgoCD
#     reject vì không có trong sourceRepos whitelist
#   - Audit log query theo `project=shopxpress-pro` (tách workload pro với
#     ArgoCD addon khác)
#   - Interview signal: senior luôn tách project, không dùng default
#
# depends_on Namespace để destinations whitelist trỏ tới namespace đã tồn tại
# (race condition nếu apply song song).
# ============================================================
resource "kubectl_manifest" "appproject" {
  yaml_body = file("${path.module}/appproject.yaml")

  depends_on = [kubectl_manifest.workload_namespace]
}

# ============================================================
# ApplicationSet — matrix generator 3 service × 3 env = 9 Application
# ============================================================
# Generator matrix:
#   - list service: gateway, products, orders
#   - list env: dev, stg, prd
#   - tích Descartes → 9 cặp {service, env}
#
# Template inject vào mỗi cặp:
#   - name: <service>-<env>           (vd gateway-dev)
#   - source.path: services/<service> (Helm chart trong repo deploy)
#   - source.helm.valueFiles: [values.yaml, values-<env>.yaml] (cascade base + override)
#   - destination.namespace: <env>    (deploy vào ns dev/stg/prd)
#   - sync-wave: gateway=1, products+orders=0 (gateway BFF chờ 2 backend ready)
#
# syncPolicy.automated:
#   - prune: true     — xoá resource khi Git xoá khỏi chart
#   - selfHeal: true  — drift back về Git nếu ai đó kubectl edit thủ công
#
# WHY tách file YAML thay vì heredoc trong TF:
#   - File `appset.yaml` cùng folder, paste nhanh vào Argo CLI khi debug
#   - heredoc dài 80+ dòng làm main.tf khó đọc
#
# WHY kubectl_manifest:
#   ApplicationSet là CRD argoproj.io/v1alpha1, plan-time validate fail nếu
#   dùng kubernetes_manifest (CRD chưa registered lúc plan). kubectl validate
#   apply-time, an toàn.
#
# depends_on AppProject để khi ApplicationSet đẻ Application, project
# `shopxpress-pro` đã tồn tại trong cluster.
# ============================================================
resource "kubectl_manifest" "appset" {
  yaml_body = file("${path.module}/appset.yaml")

  depends_on = [kubectl_manifest.appproject]
}
