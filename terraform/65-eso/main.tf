# ============================================================
# Random password — generated tại apply, KHÔNG vào git
# ============================================================
# Senior pattern: TF không bao giờ thấy raw value qua git/code review.
# random_password sinh trong RAM tại lúc apply, ghi thẳng vào SM.
# State file (S3 + KMS encrypted) lưu hash, người đọc state KHÔNG thấy plaintext.
#
# `special = false` để demo có thể đọc dễ. Production:
#   special = true + override_special = "!@#$%^&*-_+=" (tránh ký tự gãy URL/JSON).
# ============================================================
resource "random_password" "demo" {
  length  = var.demo_secret_password_length
  special = false
  upper   = true
  lower   = true
  numeric = true

  # Chỉ regen khi length thay đổi. Đổi tfvars khác KHÔNG trigger rotation.
  keepers = {
    length = var.demo_secret_password_length
  }
}

# ============================================================
# AWS Secrets Manager — secret + version
# ============================================================
# Resource tách 2: aws_secretsmanager_secret = metadata (name, KMS, tags),
# aws_secretsmanager_secret_version = value JSON. Tách giúp:
#   - Đổi value (rotation manual) KHÔNG đụng metadata
#   - Cleanup gọn: destroy version trước, secret sau (TF DAG tự xử)
#
# `recovery_window_in_days = 0`:
#   - Default 30 ngày — secret destroyed vẫn restore được trong 30 ngày
#   - Lab dùng 0 → force-delete ngay (KHÔNG bill $0.40/30 ngày sau destroy)
#   - PRODUCTION: để default 30, hoặc 7 cho dev. Đặt 0 cho prd = mất là mất.
# ============================================================
resource "aws_secretsmanager_secret" "demo" {
  name                    = var.demo_secret_name
  description             = "Demo secret synced by ESO - Sub-comp 9 Lab A++"
  recovery_window_in_days = 0

  tags = {
    Name      = var.demo_secret_name
    Component = "eso-demo-secret"
  }
}

resource "aws_secretsmanager_secret_version" "demo" {
  secret_id = aws_secretsmanager_secret.demo.id

  secret_string = jsonencode({
    username = var.demo_secret_username
    password = random_password.demo.result
  })

  # Lifecycle: nếu rotation Lambda đổi value bên ngoài TF, TF không revert.
  # Comment out để demo: TF "own" value, drift rotation = TF detect.
  # lifecycle { ignore_changes = [secret_string] }
}

# ============================================================
# IAM Policy — ESO permission đọc secret
# ============================================================
# 2 statement:
#   1. ReadShopxpressDevSecrets: scope ARN wildcard prefix = least-privilege.
#      KHÔNG dùng "*" toàn account.
#   2. ListSecrets: API ListSecrets KHÔNG support resource-level scope, BUỘC "*".
#      Tradeoff: ESO có thể list metadata mọi secret (tên thôi, không content).
#      Mitigate: bật CloudTrail + alert nếu ESO call ListSecrets nhiều bất thường.
# ============================================================
resource "aws_iam_policy" "eso_secretsmanager_read" {
  name        = local.eso_policy_name
  description = "ESO read access to ${var.project} ${var.env} secrets in Secrets Manager - Sub-comp 9"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadShopxpressDevSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        # Wildcard ăn luôn 6 ký tự suffix random AWS tự thêm vào ARN.
        # Pattern: shopxpress-pro/dev/<purpose> + 6 ký tự ngẫu nhiên.
        Resource = [
          "arn:aws:secretsmanager:${var.region}:*:secret:${var.project}/*",
        ]
      },
      {
        Sid      = "ListSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:ListSecrets"]
        Resource = "*"
      },
    ]
  })
}

# ============================================================
# IRSA role — ESO controller ServiceAccount assume role này
# ============================================================
# Dùng module/irsa shared. Caller pass:
#   - oidc_provider_arn + url từ 40-irsa
#   - sa_namespace = "external-secrets" (chart-managed)
#   - sa_name      = "external-secrets" (chart-managed default name)
#   - policy_arns  = [SM read policy ở trên]
#
# Naming: shopxpress-pro-nonprd-irsa-eso (≤64 ký tự, validate trong module).
# ============================================================
module "eso_irsa" {
  source = "../modules/irsa"

  oidc_provider_arn = data.terraform_remote_state.irsa.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.irsa.outputs.oidc_provider_url

  sa_namespace = local.eso_namespace
  sa_name      = local.eso_sa_name

  role_name        = local.eso_role_name
  role_description = "IRSA role for ESO controller in ${local.cluster_name} - Sub-comp 9"

  policy_arns = [
    aws_iam_policy.eso_secretsmanager_read.arn,
  ]

  tags = local.common_tags
}

# ============================================================
# Namespace app-demo — nơi ExternalSecret + K8s Secret đẻ ra
# ============================================================
# Tách khỏi helm release để lifecycle độc lập:
#   - helm uninstall ESO KHÔNG xoá namespace (workload trong NS không bị sweep)
#   - terraform destroy 65-eso XOÁ NS (TF own)
# Pattern senior: app pod trong NS này dùng K8s Secret demo-eso-synced qua envFrom.
# ============================================================
resource "kubernetes_namespace" "app_demo" {
  metadata {
    name = var.app_namespace

    labels = {
      project                        = var.project
      env                            = var.env
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================
# Helm release — External Secrets Operator
# ============================================================
# Chart: external-secrets/external-secrets 2.4.1 (app v2.4.1).
# Mapping verify qua `helm search repo --versions` 2026-05-09.
#
# Controller làm gì:
#   1. Watch ExternalSecret CRD trong cluster
#   2. Mỗi refreshInterval, call SM API (qua IRSA) → fetch JSON value
#   3. So sánh với K8s Secret hiện tại → patch nếu khác
#   4. Ghi status condition + emit event Kubernetes
#
# extraObjects:
#   ESO chart cho phép inject manifest YAML kèm release. Lifecycle gắn với
#   helm release (uninstall = xoá hết). Em inject 2 thứ:
#     - ClusterSecretStore: cluster-wide store config trỏ SM region apse1 + IRSA SA
#     - ExternalSecret: đặt trong NS app-demo, refresh 1m, target K8s Secret
#       "demo-eso-synced" với dataFrom extract toàn bộ JSON SM → key/value 1-1
#
# WHY ClusterSecretStore (KHÔNG SecretStore):
#   SecretStore (namespaced) admission webhook reject auth.jwt.serviceAccountRef
#   trỏ SA NS khác (multi-tenant rule). ESO controller SA nằm NS external-secrets,
#   ExternalSecret nằm NS app-demo → cross-NS = phải dùng ClusterSecretStore.
#   Đã pushback lab UI lần đầu, ghi memory.
# ============================================================
resource "helm_release" "external_secrets" {
  name       = local.eso_release_name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version

  namespace        = local.eso_namespace
  create_namespace = true

  wait    = true
  timeout = var.eso_helm_timeout_seconds
  atomic  = true

  values = [
    yamlencode({
      installCRDs  = true
      replicaCount = var.eso_replica_count

      # ----- ServiceAccount + IRSA annotation -----
      # Chart tạo SA "external-secrets" trong NS "external-secrets".
      # Annotation eks.amazonaws.com/role-arn → pod identity webhook inject
      # AWS_ROLE_ARN + AWS_WEB_IDENTITY_TOKEN_FILE env vars.
      serviceAccount = {
        create = true
        name   = local.eso_sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eso_irsa.role_arn
        }
      }

      # ----- Resource limits (sane defaults, lab) -----
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }

    }),
  ]

  depends_on = [
    aws_secretsmanager_secret_version.demo,
  ]
}

# ============================================================
# ClusterSecretStore — đường ống tới SM
# ============================================================
# WHY ClusterSecretStore (KHÔNG SecretStore):
#   SecretStore (namespaced) admission webhook reject auth.jwt.serviceAccountRef
#   trỏ SA NS khác (multi-tenant rule). ESO controller SA nằm NS external-secrets,
#   ExternalSecret nằm NS app-demo → cross-NS BUỘC dùng ClusterSecretStore.
#   Đã bị pushback lab UI lần đầu, ghi memory.
#
# depends_on helm_release để đảm bảo CRD tồn tại trước khi apply.
# ============================================================
resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = local.eso_sa_name
                namespace = local.eso_namespace
              }
            }
          }
        }
      }
    }
  })

  depends_on = [helm_release.external_secrets]
}

# ============================================================
# ExternalSecret — đơn đặt hàng cụ thể
# ============================================================
# Định nghĩa "kéo secret nào, đẻ K8s Secret tên gì, refresh bao lâu".
# dataFrom.extract: kéo TOÀN BỘ JSON object trong SM, mỗi key trong JSON
# → thành 1 key K8s Secret data tương ứng.
# Alternative: data[].remoteRef + property = "<key>" → kéo từng key riêng,
# verbose hơn nhưng schema-explicit (gãy nếu key SM thiếu, dễ debug).
# ============================================================
resource "kubectl_manifest" "external_secret_demo" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "demo-eso"
      namespace = var.app_namespace
    }
    spec = {
      refreshInterval = var.eso_refresh_interval
      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "demo-eso-synced"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = aws_secretsmanager_secret.demo.name
          }
        },
      ]
    }
  })

  depends_on = [
    helm_release.external_secrets,
    kubernetes_namespace.app_demo,
    kubectl_manifest.cluster_secret_store,
  ]
}
