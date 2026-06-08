# modules/vpc/variables.tf

variable "name_prefix" {
  description = " mango-prod  O  mango-dev "
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
}

variable "availability_zones" {
  description = "Las 2 AZs a usar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las 2 subredes públicas"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs para las 2 subredes privadas"
  type        = list(string)
}

variable "tags" {
  description = "Tags comunes aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
