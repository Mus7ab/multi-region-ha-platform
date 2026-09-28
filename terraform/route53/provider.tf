terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "three-tier-webapp-tfstate-342677169816"
    key          = "project7-route53/terraform.tfstate"
    region       = "ap-south-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "ap-south-2"
}
