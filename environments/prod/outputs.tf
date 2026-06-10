# environments/prod/outputs.tf

output "alb_dns_name" {
  description = "DNS del ALB — apunta este DNS en Route53 para api_domain y admin_domain."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB para registros Route53 tipo Alias."
  value       = module.alb.alb_zone_id
}

output "nat_public_ip" {
  description = "IP pública fija del NAT Gateway — agrégala a whitelists externas."
  value       = module.vpc.nat_public_ip
}

output "ecr_api_url" {
  description = "docker push <tag> → esta URL para mango-api"
  value       = module.ecr.api_repository_url
}

output "ecr_admin_url" {
  description = "docker push <tag> → esta URL para mango-admin"
  value       = module.ecr.admin_repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}
/*
output "api_sqs_queue_url" {
  value = module.sqs.api_queue_url
}

output "admin_sqs_queue_url" {
  value = module.sqs.admin_queue_url
}
*/
output "eventbridge_scheduler" {
  description = "Nombre del scheduler de EventBridge que dispara el cron de Laravel"
  value       = module.ecs.eventbridge_scheduler_name
}
