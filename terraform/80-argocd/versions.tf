terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Helm provider v3 (released 2025) — syntax breaking change so với 2.x.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    # kubectl 3rd party — apply-time validation, dùng cho Ingress vì:
    # Ingress không phải CRD nhưng giữ pattern thống nhất với 65-eso (CSS/ES)
    # cho mọi K8s manifest TF apply, tránh kubernetes_manifest plan-time edge.
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
