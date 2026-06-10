# modules/ecs/outputs.tf

output "ecs_api_sg_id"            { value = aws_security_group.ecs_api.id }
output "ecs_admin_sg_id"          { value = aws_security_group.ecs_admin.id }
output "ecs_workers_sg_id"        { value = aws_security_group.ecs_workers.id }
output "cluster_name"             { value = aws_ecs_cluster.main.name }
output "cluster_arn"              { value = aws_ecs_cluster.main.arn }
output "api_service_name"         { value = aws_ecs_service.api.name }
output "admin_service_name"       { value = aws_ecs_service.admin.name }
output "api_worker_service_name"  { value = aws_ecs_service.api_worker.name }
output "admin_worker_service_name"{ value = aws_ecs_service.admin_worker.name }
output "cron_task_definition_arn" { value = aws_ecs_task_definition.tasks["mango-cron"].arn }
output "execution_role_arn"       { value = aws_iam_role.execution.arn }
output "task_role_arn"            { value = aws_iam_role.task.arn }
output "eventbridge_scheduler_name" { value = aws_scheduler_schedule.cron.name }
