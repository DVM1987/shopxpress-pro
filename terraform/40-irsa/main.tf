# ============================================================
# IAM OIDC Identity Provider — singleton per cluster
# ============================================================
# Mục đích: đăng ký EKS cluster làm "Identity Provider" trong IAM,
# để STS verify được JWT token mà pod trình lên khi gọi
# `sts:AssumeRoleWithWebIdentity` (cơ chế IRSA).
#
# Without OIDC Provider → STS không có public key cluster để verify
# JWT → reject mọi AssumeRoleWithWebIdentity → IRSA fail im lặng.
#
# 3 input:
#   - url: OIDC issuer URL (có https://) — từ EKS describe-cluster
#   - client_id_list: audience JWT, fix `sts.amazonaws.com`
#   - thumbprint_list: SHA1 root CA cert chain (fetch runtime qua tls_certificate)
#
# Lưu ý phân biệt với "OIDC identity providers" trong tab EKS Access:
#   - IAM OIDC IdP (resource này) = STS verify JWT pod cho IRSA — ✅ bắt buộc
#   - EKS Access OIDC = SSO login user (Okta/Google) vào kubectl — không liên quan
# ============================================================
resource "aws_iam_openid_connect_provider" "eks" {
  url = local.oidc_issuer_url

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-eks-oidc"
    Component = "iam-oidc-provider"
  })
}

# ============================================================
# IRSA role — vpc-cni (aws-node DaemonSet)
# ============================================================
# Refactor production: chuyển vpc-cni từ node role → IRSA role riêng.
#
# Trước (Sub-comp 4): aws-node DaemonSet không có IRSA, ipamd gọi
# ec2:Assign/UnassignPrivateIp bằng quyền của EC2 instance role
# (4 managed policy attach trong Sub-comp 3, bao gồm AmazonEKS_CNI_Policy).
#
# Sau (Sub-comp 5): aws-node SA có annotation role-arn, ipamd dùng
# IRSA role riêng. Lợi ích:
#   1. Tách quyền: node role không cần CNI_Policy nữa (least-privilege)
#   2. Audit CloudTrail: API call ec2:Assign* gắn role IRSA, KHÔNG còn
#      lẫn với call SSM/ECR/etc của node
#   3. Pattern đồng nhất với LBC, ExternalDNS, ESO (cùng dùng IRSA)
#
# SA mặc định EKS Add-on tạo: kube-system/aws-node
# Audience JWT: sts.amazonaws.com (default)
#
# CHƯA gỡ AmazonEKS_CNI_Policy khỏi node role ở session này. Lý do:
# fallback safety — nếu IRSA wire sai, vpc-cni vẫn chạy bằng node role.
# Sau khi verify IRSA active (tail audit CloudTrail thấy assume role
# thành công), session sau gỡ policy khỏi node role để complete least-privilege.
# ============================================================
module "vpc_cni_irsa" {
  source = "../modules/irsa"

  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  # Pitfall: aws_iam_openid_connect_provider.url attribute strip "https://" prefix.
  # Pass raw issuer URL từ EKS data source (giữ "https://") cho module validation.
  oidc_provider_url = local.oidc_issuer_url

  sa_namespace = "kube-system"
  sa_name      = "aws-node"

  role_name        = "${local.name_prefix}-irsa-vpc-cni"
  role_description = "IRSA role for aws-node DaemonSet (vpc-cni Add-on). ENI/IP management."

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-irsa-vpc-cni"
    Component = "iam-irsa-vpc-cni"
    Workload  = "kube-system/aws-node"
  })
}

# ============================================================
# IRSA role — aws-ebs-csi-driver (controller Deployment)
# ============================================================
# EKS Add-on aws-ebs-csi-driver tạo 2 workload trong kube-system:
#   1. Deployment ebs-csi-controller (2 replica) — call EC2 API:
#      ec2:CreateVolume, AttachVolume, DetachVolume, DeleteVolume,
#      DescribeVolumes, ec2:CreateSnapshot... → cần IRSA.
#      ServiceAccount: kube-system/ebs-csi-controller-sa  ← role này.
#   2. DaemonSet ebs-csi-node — chỉ mount/format ở node level,
#      KHÔNG gọi EC2 API. Dùng node role qua hostPath, không cần IRSA.
#      ServiceAccount: kube-system/ebs-csi-node-sa (không annotate role).
#
# AWS managed policy `AmazonEBSCSIDriverPolicy` chứa đúng action set
# controller cần (CreateVolume + AttachVolume + Snapshot + KMS Decrypt
# nếu volume encrypt). Không cần customer-managed.
# ============================================================
module "ebs_csi_irsa" {
  source = "../modules/irsa"

  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = local.oidc_issuer_url

  sa_namespace = "kube-system"
  sa_name      = "ebs-csi-controller-sa"

  role_name        = "${local.name_prefix}-irsa-ebs-csi"
  role_description = "IRSA role for ebs-csi-controller Deployment. EBS volume lifecycle (Create/Attach/Snapshot)."

  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-irsa-ebs-csi"
    Component = "iam-irsa-ebs-csi"
    Workload  = "kube-system/ebs-csi-controller-sa"
  })
}

# ============================================================
# Customer-managed IAM policy — AWS Load Balancer Controller
# ============================================================
# AWS KHÔNG có managed policy đủ quyền cho LBC: controller cần
# quyền tạo/sửa ALB/NLB + Target Group + Security Group + đọc
# WAF/Shield/ACM... Tổng hợp ~250 dòng action.
#
# Policy JSON vendored từ upstream:
#   https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.3.0/docs/install/iam_policy.json
#
# Lý do vendor (KHÔNG fetch runtime qua http data source):
#   1. Reproducible: pin version chart ↔ pin version policy. Upgrade
#      LBC chart 3.3.0 → 3.4.0 = bump file `aws-load-balancer-controller-v<ver>.json`
#      có chủ đích, KHÔNG drift im lặng khi GitHub thay file.
#   2. Audit: diff policy nằm trong git history, code review thấy được.
#   3. Offline: TF apply không phụ thuộc reachability GitHub.
#
# Convention: policy file đặt `policies/aws-load-balancer-controller-v<chart_version>.json`,
# bump version cùng lúc khi upgrade chart trong 45-lbc/main.tf.
# ============================================================
resource "aws_iam_policy" "lbc" {
  name        = "${local.name_prefix}-lbc-policy"
  description = "Customer-managed policy for AWS Load Balancer Controller v3.3.0. Vendored from upstream iam_policy.json."

  policy = file("${path.module}/policies/aws-load-balancer-controller-v3.3.0.json")

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-lbc-policy"
    Component = "iam-policy-lbc"
  })
}

# ============================================================
# IRSA role — AWS Load Balancer Controller (Deployment)
# ============================================================
# LBC = K8s controller chạy 2 replica trong kube-system. Reconcile
# Ingress (class=alb) → tạo ALB + Target Group + Listener Rule.
# Reconcile Service type=LoadBalancer (annotation NLB) → tạo NLB.
#
# ServiceAccount mặc định chart eks/aws-load-balancer-controller tạo:
#   kube-system/aws-load-balancer-controller
#
# Khác ebs-csi: LBC dùng customer-managed policy (aws_iam_policy.lbc.arn),
# KHÔNG dùng AWS managed (vì AWS không cung cấp).
# ============================================================
module "lbc_irsa" {
  source = "../modules/irsa"

  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = local.oidc_issuer_url

  sa_namespace = "kube-system"
  sa_name      = "aws-load-balancer-controller"

  role_name        = "${local.name_prefix}-irsa-lbc"
  role_description = "IRSA role for AWS Load Balancer Controller. ALB/NLB/TargetGroup/SG lifecycle."

  policy_arns = [
    aws_iam_policy.lbc.arn,
  ]

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-irsa-lbc"
    Component = "iam-irsa-lbc"
    Workload  = "kube-system/aws-load-balancer-controller"
  })
}

# ============================================================
# Customer-managed IAM policy — ExternalDNS
# ============================================================
# ExternalDNS reconcile Ingress/Service annotation `external-dns.alpha.
# kubernetes.io/hostname` → tạo/sửa/xoá DNS record ở Route 53.
#
# 2 statement design (least-privilege, KHÔNG dùng `*` cho ChangeRecordSets):
#
#   Statement 1 — ChangeResourceRecordSets:
#     Scope = sub-zone arn DUY NHẤT (do2602.click apex KHÔNG động được).
#     Lý do: nếu IRSA bị compromise (pod escape), attacker chỉ poison
#     được DNS record trong sub-zone shopxpress-pro, không phá apex/sub-zone khác.
#
#   Statement 2 — List* APIs:
#     Scope = `*` BẮT BUỘC vì R53 List API KHÔNG support resource-level
#     condition (limitation của AWS, KHÔNG phải design choice).
#     ExternalDNS gọi ListHostedZones lúc startup để map domain filter
#     → zone_id. Risk thấp: List = read-only metadata, không leak record content
#     ngoài tên zone (đã public qua DNS).
#
# Pattern khác LBC (vendored JSON file): build động qua aws_iam_policy_document
# vì policy phụ thuộc subzone_arn từ Sub-comp 7a — resource ARN là contract,
# KHÔNG phải action set tĩnh.
# ============================================================
data "aws_iam_policy_document" "externaldns" {
  statement {
    sid    = "AllowChangeRecordSetsInSubZone"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      data.terraform_remote_state.subzone.outputs.subzone_arn,
    ]
  }

  statement {
    sid    = "AllowListHostedZonesAndRecords"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]

    # R53 List* không hỗ trợ resource-level condition.
    resources = ["*"]
  }
}

resource "aws_iam_policy" "externaldns" {
  name        = "${local.name_prefix}-externaldns-policy"
  description = "Customer-managed policy for ExternalDNS controller. Scoped to sub-zone ${data.terraform_remote_state.subzone.outputs.subzone_name}."

  policy = data.aws_iam_policy_document.externaldns.json

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-externaldns-policy"
    Component = "iam-policy-externaldns"
  })
}

# ============================================================
# IRSA role — ExternalDNS (Deployment in kube-system)
# ============================================================
# ExternalDNS chart `external-dns/external-dns` deploy 1 replica trong
# kube-system. Reconcile Ingress class=alb (hoặc Service type=LoadBalancer)
# → đọc annotation hostname → CRUD R53 record A/AAAA/CNAME + 1 TXT record
# (registry, marker ownership theo `txtOwnerId`).
#
# ServiceAccount mặc định chart tạo: kube-system/external-dns
# Chart version sẽ pin ở 50-externaldns/main.tf, app version v0.16.x
# (chart 1.15.x map app 0.16.x — verify qua `helm search repo --versions`).
# ============================================================
module "externaldns_irsa" {
  source = "../modules/irsa"

  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = local.oidc_issuer_url

  sa_namespace = "kube-system"
  sa_name      = "external-dns"

  role_name        = "${local.name_prefix}-irsa-externaldns"
  role_description = "IRSA role for ExternalDNS controller. R53 record CRUD scoped to sub-zone."

  policy_arns = [
    aws_iam_policy.externaldns.arn,
  ]

  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-irsa-externaldns"
    Component = "iam-irsa-externaldns"
    Workload  = "kube-system/external-dns"
  })
}
