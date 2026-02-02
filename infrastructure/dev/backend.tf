terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "ev-aluator-terraform"
    key    = "dev/terraform.tfstate"
    region = "us-east-2"
  }
}