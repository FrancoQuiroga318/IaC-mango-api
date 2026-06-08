# modules/sqs/outputs.tf

output "api_queue_url" {
  value = var.create_queues ? aws_sqs_queue.api_worker[0].url : var.existing_api_queue_url
}

output "api_queue_arn" {
  value = var.create_queues ? aws_sqs_queue.api_worker[0].arn : ""
}

output "admin_queue_url" {
  value = var.create_queues ? aws_sqs_queue.admin_worker[0].url : var.existing_admin_queue_url
}

output "admin_queue_arn" {
  value = var.create_queues ? aws_sqs_queue.admin_worker[0].arn : ""
}
