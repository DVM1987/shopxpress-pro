terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    # Kubernetes provider — quản Deployment + Service + Ingress qua TF (typed
    # resource thay vì kubernetes_manifest raw YAML để TF hiểu schema, validate
    # diff fine-grained và import được).
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
