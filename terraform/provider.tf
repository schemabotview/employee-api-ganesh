terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "employee-api-tfstate-743737183475"
    key    = "terraform/employee-api-ganesh/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region
}