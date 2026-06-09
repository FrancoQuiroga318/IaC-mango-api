# =============================================================================
# environments/dev/main.tf
# Misma arquitectura que PROD con las siguientes diferencias:
#   - 1 tarea fija por servicio (sin auto-scaling)
#   - Sin protección de borrado en ALB
#   - Menor CPU/memoria para reducir costos
#   - Logs retenidos 14 días (vs 90 en PROD)
# =============================================================================

locals {
  name_prefix = "mango-dev"

  tags = {
    Project     = "mango"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "morris-opazo"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.tags
}

module "ecr" {
  # ECR es compartido entre DEV y PROD (mismos repos, distinto tag)
  # Si quieren repos separados, cambiar name_prefix a "mango-dev"
  source      = "../../modules/ecr"
  name_prefix = "mango" # Prefijo sin ambiente para compartir repos
  tags        = local.tags
}

module "sqs" {
  source        = "../../modules/sqs"
  name_prefix   = local.name_prefix
  create_queues = var.create_sqs_queues
  tags          = local.tags
}

module "alb" {
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  alb_sg_id                  = module.sg.alb_sg_id
  acm_certificate_arn        = var.acm_certificate_arn
  api_domain                 = var.api_domain
  admin_domain               = var.admin_domain
  api_container_port         = var.api_container_port
  admin_container_port       = var.admin_container_port
  api_health_check_path      = var.api_health_check_path
  admin_health_check_path    = var.admin_health_check_path
  admin_allowed_cidrs        = var.admin_allowed_cidrs
  enable_deletion_protection = false  # Permitir destruir en DEV fácilmente
  tags                       = local.tags
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix            = local.name_prefix
  private_subnet_ids     = module.vpc.private_subnet_ids
  ecs_api_sg_id          = module.sg.ecs_api_sg_id
  ecs_admin_sg_id        = module.sg.ecs_admin_sg_id
  ecs_workers_sg_id      = module.sg.ecs_workers_sg_id
  ecr_api_url            = module.ecr.api_repository_url
  ecr_admin_url          = module.ecr.admin_repository_url
  api_target_group_arn   = module.alb.api_target_group_arn
  admin_target_group_arn = module.alb.admin_target_group_arn
  image_tag              = var.image_tag
  log_retention_days     = 14

  # Sizing DEV (menor que PROD)
  api_cpu      = 256
  api_memory   = 512
  admin_cpu    = 256
  admin_memory = 512
  worker_cpu   = 256
  worker_memory= 512
  cron_cpu     = 256
  cron_memory  = 512

  # DEV: 1 tarea fija por servicio
  api_desired_count   = 1
  admin_desired_count = 1

  # Sin auto-scaling en DEV
  enable_autoscaling = false

  # SQS
  api_queue_url   = module.sqs.api_queue_url
  admin_queue_url = module.sqs.admin_queue_url

  api_container_port      = var.api_container_port
  admin_container_port    = var.admin_container_port
  api_health_check_path   = var.api_health_check_path
  admin_health_check_path = var.admin_health_check_path

  api_environment_vars   = var.api_environment_vars
  api_secrets            = var.api_secrets
  admin_environment_vars = var.admin_environment_vars
  admin_secrets          = var.admin_secrets

  tags = local.tags
}
