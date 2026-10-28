output "ecr_url" {
  description = "Push images here"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "log_group" {
  description = "CloudWatch log group for task logs"
  value       = aws_cloudwatch_log_group.app.name
}
