# modules/ecs/variables.tf
variable "name_prefix"{
  type = string 
}
variable "private_subnet_ids"{
  type = list(string) 
}
variable "ecs_api_sg_id"{
  type = string 
}
variable "ecs_admin_sg_id"{
  type = string 
}
variable "ecs_workers_sg_id"{
  type = string
}
variable "ecr_api_url"{
  type = string 
}
variable "ecr_admin_url"{
  type = string
}
variable "api_target_group_arn"{
  type = string 
}
variable "admin_target_group_arn"{
  type = string
}
variable "image_tag"{
  type = string
  default = "latest" 
}
variable "log_retention_days"{
  type = number
  default = 30 
}

# Automatizacion de task 
variable "task_definitions" {
  description = "Mapa de task definitions. Agregar una nueva entrada para crear una nueva task."
  type = map(object({
    cpu              = number
    memory           = number
    ecr_url          = string
    port             = optional(number, null)
    health_check_path= optional(string, "/health")
    command          = optional(list(string), null)
    sqs_queue_url    = optional(string, null)
    environment_vars = optional(list(object({ name = string, value = string })), [])
    secrets          = optional(list(object({ name = string, valueFrom = string })), [])
  }))
}

# Puertos
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

# CPU / Memoria
variable "api_cpu"{
  type = number 
  default = 512 
}
variable "api_memory"  {
  type = number
  default = 1024
}
variable "admin_cpu"{
  type = number
  default = 512 
}
variable "admin_memory"{
  type = number
  default = 1024 
}
variable "worker_cpu"{
  type = number
  default = 256 
}
variable "worker_memory"{
  type = number
  default = 512
}
variable "cron_cpu"{
  type = number
  default = 256 
}
variable "cron_memory" {
  type = number
  default = 512
}

# Desired counts
variable "api_desired_count"{
  type = number
  default = 2 
}
variable "admin_desired_count" {
  type = number
  default = 1
}

# Auto-scaling
variable "enable_autoscaling" {
  type = bool
  default = false 
}
variable "api_min_count"{
  type = number
  default = 2 
}
variable "api_max_count"{
  type = number
  default = 4 
}

# SQS
variable "api_queue_url"{
  type = string
  default = "" 
}
variable "admin_queue_url"{
  type = string
  default = "" 
}

# Variables de entorno y secrets del contenedor
variable "api_environment_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}
variable "api_secrets" {
  description = "Secrets desde SSM o Secrets Manager"
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

variable "tags" {
  type = map(string)
  default = {} 
}
