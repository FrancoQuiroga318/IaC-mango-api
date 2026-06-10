# =============================================================================
# modules/alb/main.tf
# ALB público con SSL terminado via ACM.
# Host-based routing: api_domain → TG mango-api, admin_domain → TG mango-admin.
# Si admin_allowed_cidrs no está vacío, se aplica restricción de IP en el SG ALB.
# =============================================================================

# --- Application Load Balancer ----------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  enable_http2       = true

  enable_deletion_protection = var.enable_deletion_protection

}

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
    description = "HTTP redireccionamiento a HTTPS"
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

//tg, sg, task
# Target Group: mango-api 
resource "aws_lb_target_group" "api" {
  name        = "${var.name_prefix}-tg-api"
  port        = var.api_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.api_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  lifecycle { create_before_destroy = true }
}

#Target Group: mango-admin
resource "aws_lb_target_group" "admin" {
  name        = "${var.name_prefix}-tg-admin"
  port        = var.admin_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.admin_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  lifecycle { create_before_destroy = true }
}

# --- Listener HTTP (redirige todo a HTTPS) -----------------------------------
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- Listener HTTPS principal -----------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  # Default action: 404 si ninguna regla coincide
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# --- Regla host-based: api_domain → mango-api TG ----------------------------
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = [var.api_domain]
    }
  }
}

# --- Regla host-based: admin_domain → mango-admin TG ------------------------
# Si admin_allowed_cidrs no está vacío, se agrega condición de IP de origen.
resource "aws_lb_listener_rule" "admin" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin.arn
  }

  condition {
    host_header {
      values = [var.admin_domain]
    }
  }

  # Restricción de IP de origen (solo si se definen CIDRs)
  dynamic "condition" {
    for_each = length(var.admin_allowed_cidrs) > 0 ? [1] : []
    content {
      source_ip {
        values = var.admin_allowed_cidrs
      }
    }
  }
}
