# ============================================================
# Helm release — ExternalDNS
# ============================================================
# Chart: external-dns/external-dns 1.21.1 (app v0.21.0).
# Mapping verify qua `helm search repo --versions` 2026-05-09.
#
# Controller làm gì:
#   1. Watch Ingress class=alb → lấy hostname từ rules + ALB DNS từ
#      status.loadBalancer → CRUD R53 record A (alias) + 1 TXT record
#      (registry, marker ownership)
#   2. Watch Service type=LoadBalancer (annotation hostname) → tương tự
#   3. Reconcile mỗi `interval` (default 1m), drift recovery tự động
#   4. Trên từng record, tạo TXT record bên cạnh có format
#      `external-dns/owner=<txtOwnerId>` để KHÔNG override record
#      của cluster khác cùng zone.
#
# Why 1 replica (KHÔNG HA):
#   - ExternalDNS dùng leader-election Lease, chỉ 1 leader CRUD R53.
#   - Multi-replica chỉ giảm RTO failover ~15s, KHÔNG tăng throughput.
#   - Trade-off: nếu node leader die, có max ~1 phút DNS không update
#     (acceptable cho dev).
# ============================================================
resource "helm_release" "externaldns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.externaldns_chart_version

  namespace        = "kube-system"
  create_namespace = false

  # `wait`: TF block đến khi Deployment Ready + leader Lease acquired.
  wait    = true
  timeout = var.externaldns_helm_timeout_seconds

  # `atomic`: rollback tự động nếu apply fail (image pull lỗi, IRSA mismatch).
  atomic = true

  # ============================================================
  # Values — set blocks (type-safe)
  # ============================================================
  set = [
    # ----------- Provider config -----------
    {
      name  = "provider.name"
      value = "aws"
    },
    {
      name  = "env[0].name"
      value = "AWS_DEFAULT_REGION"
    },
    {
      name  = "env[0].value"
      value = var.region
    },

    # ----------- Source: chỉ watch Ingress -----------
    # KHÔNG bật `service` source vì pattern Lab A++ expose service
    # qua Ingress class=alb (IngressGroup share ALB). Service source
    # chỉ cần nếu dùng NLB Service type=LoadBalancer.
    {
      name  = "sources[0]"
      value = "ingress"
    },

    # ----------- Domain filter — least-privilege scope -----------
    # Controller chỉ touch DNS record trong sub-zone này. Nếu Ingress có
    # hostname ngoài filter → ExternalDNS skip (không tạo record).
    # Match phải với IRSA policy `route53:ChangeResourceRecordSets` resource
    # = sub-zone ARN duy nhất.
    {
      name  = "domainFilters[0]"
      value = data.terraform_remote_state.subzone.outputs.subzone_name
    },

    # ----------- Registry (TXT marker ownership) -----------
    # 1 zone có thể serve nhiều cluster. ExternalDNS tạo TXT record
    # bên cạnh record A:
    #   external-dns-<recordtype>-<recordname>  TXT  "heritage=external-dns,external-dns/owner=<txtOwnerId>"
    # Khi reconcile, controller chỉ CRUD record có TXT marker match owner_id
    # của mình → cluster A KHÔNG override record của cluster B.
    {
      name  = "registry"
      value = "txt"
    },
    {
      name  = "txtOwnerId"
      value = var.externaldns_txt_owner_id
    },
    {
      name  = "txtPrefix"
      value = "externaldns-"
    },

    # ----------- Sync policy -----------
    # sync: tạo+update+DELETE khi Ingress xoá. Production-grade cleanup.
    # upsert-only: chỉ tạo+update, KHÔNG delete → an toàn hơn cho prd
    # (record orphan thay vì DNS resolve fail).
    {
      name  = "policy"
      value = var.externaldns_policy
    },

    # ----------- Reconciliation interval -----------
    {
      name  = "interval"
      value = var.externaldns_interval
    },

    # ----------- HA -----------
    {
      name  = "replicaCount"
      value = tostring(var.externaldns_replica_count)
    },

    # ----------- ServiceAccount + IRSA -----------
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-dns"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = data.terraform_remote_state.irsa.outputs.externaldns_irsa_role_arn
    },

    # ----------- Resource limits (sane defaults) -----------
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "resources.limits.memory"
      value = "128Mi"
    },

    # ----------- Priority class -----------
    # ExternalDNS critical-ish: nếu controller down → record không update
    # (DNS resolve cũ vẫn work). KHÔNG critical bằng LBC, nhưng vẫn
    # cluster-scope service → priority cao hơn workload thường.
    {
      name  = "priorityClassName"
      value = "system-cluster-critical"
    },
  ]
}
