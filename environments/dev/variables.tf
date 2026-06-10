# environments/prod/variables.tf

# --- Red --------------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

# TASK DEFINITIONS
variable "task_definitions" {
  type = map(object({
    cpu               = number
    memory            = number
    ecr_url           = string
    port              = optional(number, null)
    health_check_path = optional(string, "/health")
    command           = optional(list(string), null)
    sqs_queue_url     = optional(string, null)
    environment_vars  = optional(list(object({ name = string, value = string })), [])
    secrets           = optional(list(object({ name = string, valueFrom = string })), [])
  }))
}
# --- RDS existente ----------------------------------------------------------
variable "rds_security_group_id" {
  description = "SG ID de la RDS existente. Terraform agrega reglas de ingress desde ECS."
  type        = string
}


# --- ACM --------------------------------------------------------------------
variable "acm_certificate_arn" {
  description = "ARN del certificado ACM existente (wildcard o multi-dominio)."
  type        = string
}

# --- Dominios ---------------------------------------------------------------
variable "api_domain" {
  description = "Dominio de mango-api (ej: api.mango.com)"
  type        = string
}

variable "admin_domain" {
  description = "Dominio de mango-admin (ej: admin.mango.com)"
  type        = string
}

variable "admin_allowed_cidrs" {
  description = "CIDRs con acceso a mango-admin. Vacío = público. Ej: [\"203.0.113.0/32\"]"
  type        = list(string)
  default     = []
}

# --- Contenedor -------------------------------------------------------------
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
variable "image_tag"{
  type = string
  default = "latest" 
}

# --- SQS --------------------------------------------------------------------
variable "create_sqs_queues" {
  description = "true = Terraform crea las colas. false = ya existen."
  type        = bool
  default     = true
}

# --- Variables de entorno del contenedor ------------------------------------
variable "api_environment_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "api_secrets" {
  description = "Secrets desde SSM Parameter Store o Secrets Manager"
  type        = list(object({ name = string, valueFrom = string }))
  default     = []
}

variable "admin_environment_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "admin_secrets" {
  type    = list(object({ name = string, valueFrom = string }))
  default = []
}

## RDS
variable "rds_security_group_id" {
  description = "SG ID de la RDS existente. Terraform agrega reglas de ingress desde ECS."
  type        = string
}