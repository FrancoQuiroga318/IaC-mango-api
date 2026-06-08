# modules/sg/outputs.tf

output "alb_sg_id"          { value = aws_security_group.alb.id }
output "ecs_api_sg_id"      { value = aws_security_group.ecs_api.id }
output "ecs_admin_sg_id"    { value = aws_security_group.ecs_admin.id }
output "ecs_workers_sg_id"  { value = aws_security_group.ecs_workers.id }
