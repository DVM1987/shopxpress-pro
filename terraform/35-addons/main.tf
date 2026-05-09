# ============================================================
# EKS Add-ons — 3 core
# ============================================================
# Self-managed bootstrap vs EKS Add-on:
#   - Self-managed: cluster create tự deploy aws-node + kube-proxy default,
#     bạn tự upgrade qua kubectl apply manifest. Coredns cũng tương tự.
#   - EKS Add-on: AWS managed lifecycle, version selectable qua API,
#     auto-rotate khi cluster upgrade, configuration_values JSON khai báo.
# Pattern production senior: chuyển sang Add-on để có audit trail + auto-rotate.
#
# resolve_conflicts_on_create = "OVERWRITE": Add-on TF replace pod self-managed
# đang chạy. Pod sẽ bị recreate (rolling), aws-node ~30s/node, coredns ~1 min.
# ============================================================

# ----------------------------------------------------------
# vpc-cni — CNI plugin, KEY component cho networking pod
# ----------------------------------------------------------
# DaemonSet aws-node, mỗi pod chạy:
#   - Container chính: aws-vpc-cni-init + aws-vpc-cni
#   - ipamd binary: track ENI + secondary IP / prefix per node
# Prefix Delegation activate qua env ENABLE_PREFIX_DELEGATION=true
# → kubelet capacity 110 (đã set Sub-comp 3) sẽ MATCH IP allocation thật
# (trước đó kubelet=110 nhưng vpc-cni cấp ~17 → 17 win, max-pods thực = 17).
#
# IRSA: production nên gắn IAM role qua service_account_role_arn để aws-node
# có permission ec2:Assign/UnassignPrivateIp riêng (không qua node role).
# Sub-comp 5 sẽ refactor — giờ vẫn fallback node role (4 policy attach Sub-comp 3).
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = local.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = var.addon_resolve_conflicts
  resolve_conflicts_on_update = var.addon_resolve_conflicts

  configuration_values = local.vpc_cni_config

  # IRSA wiring (Sub-comp 5): aws-node SA assume role qua OIDC.
  # Field này tells EKS Add-on annotate ServiceAccount kube-system/aws-node
  # với eks.amazonaws.com/role-arn → kubelet mount JWT vào pod aws-node.
  # ipamd dùng JWT gọi sts:AssumeRoleWithWebIdentity → temp creds cho ec2:*.
  service_account_role_arn = data.terraform_remote_state.irsa.outputs.vpc_cni_irsa_role_arn

  tags = merge(local.common_tags, {
    Component = "eks-addon-vpc-cni"
    AddonName = "vpc-cni"
  })
}

# ----------------------------------------------------------
# kube-proxy — Service ClusterIP → Pod IP iptables/IPVS rule
# ----------------------------------------------------------
# DaemonSet kube-proxy, mode iptables (default) hoặc ipvs (high-scale > 1000 svc).
# Không cần IRSA, không cần configuration. Just version pinning + auto-rotate.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = local.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = var.addon_resolve_conflicts
  resolve_conflicts_on_update = var.addon_resolve_conflicts

  tags = merge(local.common_tags, {
    Component = "eks-addon-kube-proxy"
    AddonName = "kube-proxy"
  })
}

# ----------------------------------------------------------
# coredns — Cluster DNS (svc.cluster.local resolution)
# ----------------------------------------------------------
# Deployment 2 replica (NOT DaemonSet) — vì DNS query rate cao nhưng
# replicas đủ tải, không cần 1 pod/node.
# CRITICAL: phải apply SAU MNG vì Deployment pod cần node Ready để schedule.
# Không có node = pod Pending = Add-on stuck CREATING forever.
# Memory pitfall: project_eks_addon_order_pitfall.md
resource "aws_eks_addon" "coredns" {
  cluster_name                = local.cluster_name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = var.addon_resolve_conflicts
  resolve_conflicts_on_update = var.addon_resolve_conflicts

  tags = merge(local.common_tags, {
    Component = "eks-addon-coredns"
    AddonName = "coredns"
  })

  # Explicit depends_on cho coredns vì Deployment phải có node Ready.
  # data "terraform_remote_state.mng" ở data.tf đã enforce thứ tự apply
  # giữa state Sub-comp 3 → 4, nhưng explicit cho rõ intent.
  depends_on = [data.terraform_remote_state.mng]
}

# ----------------------------------------------------------
# aws-ebs-csi-driver — EBS PersistentVolume provisioner (CSI)
# ----------------------------------------------------------
# Workload structure khi Add-on cài xong:
#   - Deployment ebs-csi-controller (2 replica, leader-elect)
#       SA: kube-system/ebs-csi-controller-sa  ← IRSA wire ở đây
#       Container: csi-provisioner + csi-attacher + csi-snapshotter +
#                  csi-resizer + liveness-probe + ebs-plugin
#       Gọi EC2 API: CreateVolume/AttachVolume/CreateSnapshot/...
#   - DaemonSet ebs-csi-node (1 pod/node)
#       SA: kube-system/ebs-csi-node-sa (KHÔNG cần IRSA, dùng hostPath)
#       Mount/format EBS device tại host filesystem cho kubelet.
#
# Tại sao là Deployment + DaemonSet (KHÔNG phải DaemonSet duy nhất)?
#   → CSI spec tách 2 plane:
#     - Controller plane (centralize): provision/attach API call → cần
#       leader-elect tránh race condition khi 2 pod cùng CreateVolume.
#     - Node plane (per-node): mount filesystem chỉ làm được ở node thật
#       → DaemonSet 1 pod/node.
#
# CRITICAL: phải apply SAU MNG vì controller Deployment cần node Ready.
# Cùng lý do với coredns Add-on → cùng pattern depends_on.
#
# StorageClass mặc định: Add-on KHÔNG tự tạo SC. Sau apply phải:
#   - Hoặc apply SC YAML thủ công (gp3 default class)
#   - Hoặc enable storageClasses qua configuration_values (CSI 1.30+)
# Em sẽ tạo SC ở Buổi 10 trước khi cài kube-prometheus-stack.
resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name                = local.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.aws_ebs_csi_driver.version
  resolve_conflicts_on_create = var.addon_resolve_conflicts
  resolve_conflicts_on_update = var.addon_resolve_conflicts

  # IRSA wiring: controller pod assume role qua ebs-csi-controller-sa.
  # Add-on annotate SA với eks.amazonaws.com/role-arn → kubelet mount
  # JWT vào pod controller → SDK gọi sts:AssumeRoleWithWebIdentity →
  # temp creds cho ec2:CreateVolume/AttachVolume/...
  service_account_role_arn = data.terraform_remote_state.irsa.outputs.ebs_csi_irsa_role_arn

  tags = merge(local.common_tags, {
    Component = "eks-addon-ebs-csi"
    AddonName = "aws-ebs-csi-driver"
  })

  depends_on = [data.terraform_remote_state.mng]
}
