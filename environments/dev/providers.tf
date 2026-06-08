# environments/prod/providers.tf

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 para estado compartido (recomendado en PROD)
  # Descomentar y configurar antes del primer apply:
  # backend "s3" {
  #   bucket         = "mango-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "mango-terraform-locks"
  # }
}

provider "aws" {
  region = "us-east-1"
}
