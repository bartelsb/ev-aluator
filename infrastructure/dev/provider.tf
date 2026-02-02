provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      OwnedBy         = "Terraform"
      Project         = "ev-aluator"
      Environment     = "dev-${terraform.workspace}"
    }
  }
}