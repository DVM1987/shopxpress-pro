terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "shared"
      Component   = "tf-bootstrap"
      ManagedBy   = "terraform"
      Owner       = "DE000189"
    }
  }
}
