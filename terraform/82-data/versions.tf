terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Helm provider v3 (cùng pattern 45-lbc / 50-externaldns / 65-eso) —
    # syntax `kubernetes = {}` argument map, KHÔNG nested block.
    # Tránh bug `invalid_reference` của 2.17 với Bitnami chart
    # (project_helm_provider_3_migration.md).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
