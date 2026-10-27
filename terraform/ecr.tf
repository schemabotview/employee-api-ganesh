resource "aws_ecr_repository" "app" {
  name         = var.app_name
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Owner  = "ganesh"
    Course = "BD CLP"
  }
}