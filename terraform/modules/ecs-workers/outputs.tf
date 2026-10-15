output "cluster_name" {
  description = "Nombre del clúster ECS."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Nombre del servicio ECS del worker."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN de la Task Definition activa."
  value       = aws_ecs_task_definition.this.arn
}

output "execution_role_arn" {
  description = "Rol usado por Fargate para iniciar la tarea."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "Rol utilizado por el código del worker."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "Log group de CloudWatch del worker."
  value       = aws_cloudwatch_log_group.this.name
}
