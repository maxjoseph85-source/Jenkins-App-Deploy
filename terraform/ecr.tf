# ECR repository for the application image
resource "aws_ecr_repository" "app" {
  name                 = "hello-world-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # lets terraform destroy remove the repo even if it still has images

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.cluster_name
  }
}

# Keep only the 10 most recent images to save storage costs
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
      action = {
        type = "expire"
      }
    }]
  })
}