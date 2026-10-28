terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Shared team bucket, one prefix per person.
  backend "s3" {
    bucket = "employee-api-tfstate-743737183475"
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
