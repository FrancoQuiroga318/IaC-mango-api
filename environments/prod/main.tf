# =============================================================================
# environments/prod/main.tf
# Orquesta todos los módulos para el entorno de PRODUCCIÓN.
# =============================================================================

locals {
  name_prefix = "mango-prod"

  tags = {
    Project     = "mango"
    Environment = "prod"
    ManagedBy   = "Terraform"
    Owner       = "morris-opazo"
  }
}

# --- VPC --------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.tags
}

# --- ECR --------------------------------------------------------------------
module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = local.name_prefix
  tags        = local.tags
}

# --- SQS --------------------------------------------------------------------
module "sqs" {
  source        = "../../modules/sqs"
  name_prefix   = local.name_prefix
  create_queues = var.create_sqs_queues
  tags          = local.tags
}

# --- ALB --------------------------------------------------------------------
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
  enable_deletion_protection = true  # Protección en PROD
  tags                       = local.tags
}

# --- ECS --------------------------------------------------------------------
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
  log_retention_days     = 90

  # Sizing PROD
  api_cpu     = 512
  api_memory  = 1024
  admin_cpu   = 512
  admin_memory= 1024
  worker_cpu  = 256
  worker_memory = 512
  cron_cpu    = 256
  cron_memory = 512

  # Conteo PROD — mango-api: min 2 (cubre 2 AZs)
  api_desired_count   = 2
  admin_desired_count = 1

  # Auto-scaling PROD: CPU 80%, min 2, max 4
  enable_autoscaling = true
  api_min_count      = 2
  api_max_count      = 4

  # SQS
  api_queue_url   = module.sqs.api_queue_url
  admin_queue_url = module.sqs.admin_queue_url

  api_container_port    = var.api_container_port
  admin_container_port  = var.admin_container_port
  api_health_check_path = var.api_health_check_path
  admin_health_check_path = var.admin_health_check_path

  api_environment_vars   = var.api_environment_vars
  api_secrets            = var.api_secrets
  admin_environment_vars = var.admin_environment_vars
  admin_secrets          = var.admin_secrets

  tags = local.tags
}
