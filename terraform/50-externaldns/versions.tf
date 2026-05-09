terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Helm provider v3 (released 2025): syntax breaking change so với 2.x.
    # Pattern dùng từ Sub-comp 6 LBC trở đi (project_helm_provider_3_migration.md).
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
