locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_id

  # 10 tag chuẩn enterprise
  common_tags = {
    Project            = var.project
    Environment        = var.env
    Component          = "eks-addons"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Repo               = var.repo_url
    DataClassification = var.data_classification
    BackupPolicy       = var.backup_policy
    CreatedBy          = var.created_by
  }

  # ============================================================
  # vpc-cni configuration_values JSON
  # ============================================================
  # Schema reference: aws describe-addon-configuration --addon-name vpc-cni
  # --addon-version <ver> --query configurationSchema
  #
  # Prefix Delegation explained:
  #   - Default mode: 1 ENI = N secondary IP (t3.medium = 6 ENI × 12 IP - 6 = 66, AWS cap 17 max-pods)
  #   - PD mode: 1 ENI = N /28 prefix, mỗi prefix = 16 IP → 6 × 16 = 96 IP (cap 110 by AWS table)
  # WARM_PREFIX_TARGET=1: vpc-cni giữ sẵn 1 prefix idle (16 IP) cho cold-start.
  # Tăng = pod schedule nhanh nhưng waste IP CIDR.
  #
  # `jsonencode` ép TF object → JSON string đúng format AWS expect (KHÔNG HCL).
  # ============================================================
  vpc_cni_config = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = var.enable_prefix_delegation ? "true" : "false"
      WARM_PREFIX_TARGET       = tostring(var.warm_prefix_target)
    }
  })
}
