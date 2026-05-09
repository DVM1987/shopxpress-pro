locals {
  # Naming prefix dùng cho IAM Role / Launch Template / MNG name
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_id
  name_prefix  = "${local.cluster_name}-${var.node_group_name}"

  # 10 tag chuẩn enterprise — Component default = "eks-mng" (sub-resource override khi cần)
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "eks-mng"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }

  # ============================================================
  # User data — MIME multipart cho AL2023 nodeadm
  # ============================================================
  # AL2023 user_data format = MIME multipart, mỗi part là 1 NodeConfig YAML.
  # Khi MNG dùng Custom LT KHÔNG có AMI ID → MNG tự inject bootstrap NodeConfig
  # phía sau, AWS-internal merger ráp 2 part lại thành 1 nodeadm config.
  #
  # Phần override duy nhất ở đây = kubelet.config.maxPods=110.
  # Mục đích: chuẩn bị cho Sub-comp 4 vpc-cni ENABLE_PREFIX_DELEGATION=true.
  # Không có override này, kubelet vẫn dừng ở 17 pod/node mặc dù vpc-cni
  # cấp 110 IP/node → waste IP.
  #
  # Pitfall (memory project_eks_prefix_delegation.md): Default LT KHÔNG sửa
  # được, AL2023 BẮT BUỘC MIME (không chấp nhận shell script bootstrap.sh).
  # ============================================================
  user_data_mime = <<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: application/node.eks.aws

    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: ${var.max_pods}

    --BOUNDARY--
  EOT
}
