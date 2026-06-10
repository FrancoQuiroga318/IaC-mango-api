# =============================================================================
# modules/ecs/main.tf
# ECS Cluster + 5 Task Definitions:
#   1. mango-api         → Service con ALB, auto-scaling por CPU (solo PROD)
#   2. mango-admin       → Service con ALB, 1 tarea fija, sin auto-scaling
#   3. mango-api-worker  → Service sin ALB, 1 tarea fija, consume SQS
#   4. mango-admin-worker→ Service sin ALB, 1 tarea fija, consume SQS
#   5. cron-task         → Solo Task Definition, disparada por EventBridge
# =============================================================================
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

## 
# SG de mango-api tasks
# Solo acepta tráfico del ALB en el puerto del contenedor
resource "aws_security_group" "ecs_api" {
  name        = "${var.name_prefix}-sg-ecs-api"
  description = "mango-api Fargate tasks: solo tráfico desde ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Desde ALB"
    from_port       = var.api_container_port
    to_port         = var.api_container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    description = "Salida irrestricta (ECR, SQS, CloudWatch, RDS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
}

# --- SG de mango-admin tasks ------------------------------------------------
# Si admin_allowed_cidrs está vacío → acepta del ALB sin filtro extra.
# Si tiene IPs → el ALB ya filtra en su propio SG.
resource "aws_security_group" "ecs_admin" {
  name        = "${var.name_prefix}-sg-ecs-admin"
  description = "mango-admin Fargate tasks: solo tráfico desde ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Desde ALB"
    from_port       = var.admin_container_port
    to_port         = var.admin_container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
}

# --- SG de Workers (api-worker, admin-worker, cron) -------------------------
# Sin ingress (no exponen puertos). Solo egreso para SQS, ECR, CloudWatch.
resource "aws_security_group" "ecs_workers" {
  name        = "${var.name_prefix}-sg-ecs-workers"
  description = "Workers y cron tasks: sin ingress, solo egreso"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
}


# --- Regla en el SG de RDS existente ----------------------------------------
# Permite que las tasks ECS accedan a la RDS ya creada.
# Se agrega como regla al SG existente pasado como variable.
resource "aws_security_group_rule" "rds_from_ecs_api" {
  type                     = "ingress"
  from_port                = 5432 
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.ecs_api.id
  description              = "mango-api tasks → RDS"
}

resource "aws_security_group_rule" "rds_from_ecs_admin" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.ecs_admin.id
  description              = "mango-admin tasks → RDS"
}

resource "aws_security_group_rule" "rds_from_ecs_workers" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.ecs_workers.id
  description              = "Workers y cron - RDS"
}

# =============================================================================
# IAM — Roles con mínimo privilegio
# =============================================================================

# Execution Role: ECS usa este role para arrancar el contenedor (pull ECR, logs)
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role: la APLICACIÓN usa este role en tiempo de ejecución (SQS, S3, etc.)
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy" "task_policy" {
  name = "${var.name_prefix}-ecs-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSExec"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Role: para disparar la cron task
resource "aws_iam_role" "eventbridge_cron" {
  name = "${var.name_prefix}-eventbridge-cron-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy" "eventbridge_cron" {
  name = "${var.name_prefix}-eventbridge-cron-policy"
  role = aws_iam_role.eventbridge_cron.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = aws_ecs_task_definition.tasks["mango-cron"].arn
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [
          aws_iam_role.execution.arn,
          aws_iam_role.task.arn
        ]
      }
    ]
  })
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "services" {
  for_each = toset([
    "mango-api",
    "mango-admin",
    "mango-api-worker",
    "mango-admin-worker",
    "mango-cron"
  ])

  name              = "/ecs/${var.name_prefix}/${each.key}"
  retention_in_days = var.log_retention_days

}

# =============================================================================
# ECS Cluster
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 1
  }
}

# Task Automatizadas

resource "aws_ecs_task_definition" "tasks" {
  for_each = var.task_definitions

  family                   = "${var.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${each.value.ecr_url}:${var.image_tag}"
    essential = true
    command   = lookup(each.value, "command", null)

    portMappings = each.value.port != null ? [{
      containerPort = each.value.port
      protocol      = "tcp"
    }] : []

    environment = concat(
      each.value.environment_vars,
      each.value.sqs_queue_url != null ? [{ name = "SQS_QUEUE", value = each.value.sqs_queue_url }] : []
    )

    secrets = each.value.secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.name_prefix}/${each.key}"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = each.value.port != null ? {
      command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}${each.value.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    } : null
  }])
}
# =============================================================================
# ECS Services
# =============================================================================

# --- Service: mango-api -----------------------------------------------------
resource "aws_ecs_service" "api" {
  name                              = "${var.name_prefix}-mango-api"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.tasks["mango-api"].arn
  desired_count                     = var.api_desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60
  force_new_deployment              = true
  enable_execute_command            = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_api.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "mango-api"
    container_port   = var.api_container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# --- Service: mango-admin ---------------------------------------------------
resource "aws_ecs_service" "admin" {
  name                              = "${var.name_prefix}-mango-admin"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.admin.arn
  desired_count                     = var.admin_desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60
  force_new_deployment              = true
  enable_execute_command            = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_api.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.admin_target_group_arn
    container_name   = "mango-admin"
    container_port   = var.admin_container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# --- Service: mango-api-worker ----------------------------------------------
resource "aws_ecs_service" "api_worker" {
  name                 = "${var.name_prefix}-mango-api-worker"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.api_worker.arn
  desired_count        = 1
  launch_type          = "FARGATE"
  platform_version     = "LATEST"
  force_new_deployment = true
  enable_execute_command = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_api.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# --- Service: mango-admin-worker --------------------------------------------
resource "aws_ecs_service" "admin_worker" {
  name                 = "${var.name_prefix}-mango-admin-worker"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.admin_worker.arn
  desired_count        = 1
  launch_type          = "FARGATE"
  platform_version     = "LATEST"
  force_new_deployment = true
  enable_execute_command = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_api.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# =============================================================================
# Auto-Scaling — Solo mango-api, solo en PROD (controlado por variable)
# =============================================================================

resource "aws_appautoscaling_target" "api" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.api_max_count
  min_capacity       = var.api_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.name_prefix}-api-scale-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 80
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# =============================================================================
# EventBridge Scheduler — Cron task cada minuto
# =============================================================================

resource "aws_scheduler_schedule" "cron" {
  name       = "${var.name_prefix}-laravel-scheduler"
  group_name = "default"

  # Ejecuta cada minuto (equivale al cron de Linux: * * * * *)
  schedule_expression = "rate(1 minute)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.eventbridge_cron.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.cron.arn
      launch_type         = "FARGATE"
      task_count          = 1

      network_configuration {
        assign_public_ip = false
        security_groups  = [aws_security_group.ecs_api.id]
        subnets          = var.private_subnet_ids
      }
    }

    # Descartar si la tarea anterior aún no termina (evita acumulación)
    retry_policy {
      maximum_retry_attempts       = 0
      maximum_event_age_in_seconds = 60
    }
  }

}

