terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Helm provider v3 (released 2025): syntax breaking change so với 2.x.
    # Pattern dùng từ Sub-comp 6 LBC trở đi.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    # kubernetes provider — quản kubernetes_namespace app-demo.
    # KHÔNG dùng kubernetes_manifest cho CSS/ES vì plan-time validate CRD;
    # CSS/ES được inject qua helm extraObjects (apply-time).
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    # random provider — sinh demo password 32 ký tự ghi thẳng SM.
    # Pattern senior: TF không nắm raw secret, value chỉ tồn tại trong RAM
    # tại thời điểm apply, sau đó nằm encrypted ở SM + S3 state (KMS).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # kubectl provider 3rd party — cần cho ClusterSecretStore + ExternalSecret.
    # WHY KHÔNG hashicorp kubernetes_manifest:
    #   kubernetes_manifest validate CRD schema tại plan-time. ESO CRD chỉ
    #   tồn tại sau khi helm release cài → plan đầu tiên fail.
    # WHY KHÔNG helm extraObjects:
    #   helm v3 validate kind tại template-time (client side), CRD chưa có
    #   trong K8s discovery → "no matches for kind ClusterSecretStore".
    # gavinbunney/kubectl giải quyết: validate apply-time, sau khi CRD existed.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.18"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
