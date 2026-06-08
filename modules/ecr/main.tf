# modules/ecr/main.tf
# 2 repositorios privados: mango-api y mango-admin.
# Los workers usan la misma imagen que su app con distinto command.

locals {
  repos = ["mango-api", "mango-admin"]
}

resource "aws_ecr_repository" "main" {
  for_each = toset(local.repos)

  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

}

# Política de ciclo de vida: últimas 10 imágenes tagged, untagged expiran a 7 días
resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = aws_ecr_repository.main
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener las últimas 10 imágenes tagged"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-", "release-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Eliminar imágenes untagged después de 7 días"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
