# modules/ecr/outputs.tf

output "api_repository_url" {
  value = aws_ecr_repository.main["mango-api"].repository_url
}

output "admin_repository_url" {
  value = aws_ecr_repository.main["mango-admin"].repository_url
}

output "api_repository_arn" {
  value = aws_ecr_repository.main["mango-api"].arn
}

output "admin_repository_arn" {
  value = aws_ecr_repository.main["mango-admin"].arn
}
