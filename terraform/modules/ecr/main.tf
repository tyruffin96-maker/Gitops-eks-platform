# ECR is AWS's private Docker registry — like Docker Hub but inside your AWS account
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/${var.app_name}"
  image_tag_mutability = "MUTABLE"  # Allows overwriting tags (useful in dev)

  image_scanning_configuration {
    scan_on_push = true  # Automatically scans images for CVEs on push
  }

  tags = {
    Name        = "${var.project_name}-${var.app_name}"
    Environment = var.environment
  }
}

# Lifecycle policy: keep only the last 10 images to control storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}