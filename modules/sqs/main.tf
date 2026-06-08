
# modules/sqs/main.tf
# Colas SQS para mango-api-worker (6 jobs) y mango-admin-worker (3 jobs).
# Se crea solo si var.create_queues = true.
# Si ya existen, pasar los ARNs/URLs como variables en el módulo ECS.


resource "aws_sqs_queue" "api_worker" {
  count = var.create_queues ? 1 : 0

  name                       = "${var.name_prefix}-mango-api-jobs"
  visibility_timeout_seconds = 90
  message_retention_seconds  = 86400  # 1 día
  receive_wait_time_seconds  = 20     # Long polling

  # Dead Letter Queue para mensajes fallidos
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.api_worker_dlq[0].arn
    maxReceiveCount     = 5
  })
  
}

resource "aws_sqs_queue" "api_worker_dlq" {
  count = var.create_queues ? 1 : 0

  name                      = "${var.name_prefix}-mango-api-jobs-dlq"
  message_retention_seconds = 1209600 # 14 días

}

resource "aws_sqs_queue" "admin_worker" {
  count = var.create_queues ? 1 : 0

  name                       = "${var.name_prefix}-mango-admin-jobs"
  visibility_timeout_seconds = 90
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.admin_worker_dlq[0].arn
    maxReceiveCount     = 5
  })
  
}

resource "aws_sqs_queue" "admin_worker_dlq" {
  count = var.create_queues ? 1 : 0

  name                      = "${var.name_prefix}-mango-admin-jobs-dlq"
  message_retention_seconds = 1209600
  
}
