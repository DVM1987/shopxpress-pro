# ============================================================
# Helm release — AWS Load Balancer Controller
# ============================================================
# Chart: eks/aws-load-balancer-controller v3.3.0 (app v3.3.0 — chart 3.x
# unify chart_version = app_version, khác chart 1.x mapping 1.13.x → v2.13.x).
#
# Controller làm gì:
#   1. Watch Ingress class=alb → tạo ALB + Listener + Target Group + Rules
#      (target type = ip, traffic đi thẳng vào pod IP qua VPC, KHÔNG kube-proxy)
#   2. Watch Service type=LoadBalancer + annotation NLB → tạo NLB
#   3. Reconcile mỗi ~30s, drift recovery tự động
#
# 2 replica HA: 1 leader (election qua Lease object), 1 standby. Nếu leader
# pod crash → standby thắng election trong ~15s.
#
# Webhook validate Ingress: chart deploy ValidatingWebhookConfiguration kiểm
# tra annotation hợp lệ trước khi kube-apiserver accept Ingress object.
# ============================================================
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version

  namespace        = "kube-system"
  create_namespace = false

  # `wait`: TF block đến khi tất cả resource trong release Healthy
  # (Deployment Ready, Webhook resolvable). Cần thiết vì sau LBC, Sub-comp
  # 50 ExternalDNS sẽ tạo Ingress phụ thuộc IngressClass `alb`.
  wait    = true
  timeout = var.lbc_helm_timeout_seconds

  # `atomic`: nếu apply fail (pod CrashLoopBackOff, webhook timeout) → TF
  # tự rollback release về state trước. Production-grade: tránh release
  # "dirty" half-applied phải fix tay.
  atomic = true

  # ============================================================
  # Values — set blocks (type-safe, dễ diff hơn YAML literal)
  # ============================================================
  set = [
    # ----------- Cluster identity -----------
    {
      name  = "clusterName"
      value = local.cluster_name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = data.terraform_remote_state.vpc.outputs.vpc_id
    },

    # ----------- ServiceAccount + IRSA -----------
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = data.terraform_remote_state.irsa.outputs.lbc_irsa_role_arn
    },

    # ----------- HA -----------
    {
      name  = "replicaCount"
      value = tostring(var.lbc_replica_count)
    },

    # ----------- Best practice 2024+ -----------
    # enableServiceMutatorWebhook=false: KHÔNG mutate Service annotation
    # tự động. Lý do: trước đây chart auto-add `service.beta.kubernetes.io/aws-load-balancer-type=external`
    # vào mọi Service type=LoadBalancer → drift với manifest YAML user define.
    # AWS recommend tắt từ v2.5+.
    {
      name  = "enableServiceMutatorWebhook"
      value = "false"
    },

    # ----------- Resource limits (sane defaults) -----------
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "resources.limits.memory"
      value = "256Mi"
    },

    # ----------- Priority class (system-cluster-critical) -----------
    # Pod LBC chạy critical path: nếu ALB controller down → mọi Ingress
    # change pending. Set priorityClassName để kubelet KHÔNG evict khi
    # node memory pressure, ưu tiên schedule trước workload thường.
    {
      name  = "priorityClassName"
      value = "system-cluster-critical"
    },
  ]
}
