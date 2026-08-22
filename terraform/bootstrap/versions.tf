//Este archivo:
// Fija una familia compatible de Terraform.
// Evita saltos automáticos a Terraform 2.x.
// Declara oficialmente el provider AWS.
// Centraliza región y etiquetas.


terraform {
  backend "s3" {
  bucket       = "ticketflow-tfstate-989367328179-us-east-1"
  key          = "bootstrap/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
  }
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "ticketflow"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}