# modules/alb/outputs.tf

output "alb_arn"              { value = aws_lb.main.arn }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "alb_dns_name"         { value = aws_lb.main.dns_name }
output "alb_zone_id"          { value = aws_lb.main.zone_id }
output "api_target_group_arn" { value = aws_lb_target_group.api.arn }
output "admin_target_group_arn" { value = aws_lb_target_group.admin.arn }
output "https_listener_arn"   { value = aws_lb_listener.https.arn }
