terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket is supplied at init time by bootstrap/backend.hcl so the same
  # config works from a laptop and from CI.
  backend "s3" {
    key    = "terraform/employee-api-ganesh/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.app_name
      ManagedBy = "terraform"
    }
  }
}
