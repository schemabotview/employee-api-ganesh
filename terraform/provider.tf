terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "sruthi-glue-miniproject "
    key    = "terraform/employee-api-sruthi/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.region
}