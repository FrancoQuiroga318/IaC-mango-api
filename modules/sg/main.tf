
# modules/sg/main.tf
# Security Groups para ALB, tareas ECS y acceso a RDS existente.


#SG del ALB (tráfico HTTPS desde internet)
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "ALB: acepta HTTPS desde internet, permite todo saliente"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP → redirigir a HTTPS (listener de redirección)
  ingress {
    description = "HTTP (redirección a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //CICLO DE VIDA LO DEJO???
  lifecycle { create_before_destroy = true }
}

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
    security_groups = [aws_security_group.alb.id]
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
    security_groups = [aws_security_group.alb.id]
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
  from_port                = 5432 # Cambiar a 3306 si es MySQL
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
  description              = "Workers y cron → RDS"
}
