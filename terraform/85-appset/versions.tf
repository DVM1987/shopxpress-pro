terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # kubectl 3rd party — apply Namespace + ArgoCD CRD (AppProject, ApplicationSet).
    # Pattern thống nhất với 65-eso và 80-argocd: mọi K8s manifest TF apply qua
    # kubectl_manifest để tránh kubernetes_manifest plan-time edge với CRD chưa
    # tồn tại lúc plan.
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
