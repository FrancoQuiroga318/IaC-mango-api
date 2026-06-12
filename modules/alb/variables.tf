# modules/alb/variables.tf

variable "name_prefix"{
  type = string 
}
variable "vpc_id"{
  type = string 
}
variable "public_subnet_ids"{
  type = list(string) 
}
variable "acm_certificate_arn"{
  type = string 
}
variable "api_domain"{ 
  type = string 
}
variable "admin_domain"{ 
  type = string 
}
variable "api_container_port"{ 
  type = number
  default = 80 
}
variable "admin_container_port"{ 
  type = number
  default = 80 
}
variable "api_health_check_path"{
  type = string
  default = "/health" 
}
variable "admin_health_check_path"{ 
  type = string
  default = "/health"
}
variable "enable_deletion_protection"{ 
  type = bool
  default = false 
}
variable "tags"{ 
  type = map(string)
  default = {} 
}

variable "admin_allowed_cidrs" {
  description = "CIDRs con acceso a mango-admin. Vacío = acceso público."
  type        = list(string)
  default     = []
}
