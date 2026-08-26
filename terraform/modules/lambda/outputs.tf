/*
Outputs del módulo Lambda.

Permiten integrar observabilidad, CI/CD y otros módulos sin repetir nombres o
consultar manualmente recursos en AWS.
*/

output "function_name" {
  description = "Nombre de la función Lambda de auditoría."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN de la función Lambda."
  value       = aws_lambda_function.this.arn
}

output "execution_role_arn" {
  description = "ARN del rol IAM de ejecución de la función."
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  description = "Nombre del grupo de CloudWatch Logs de la función."
  value       = aws_cloudwatch_log_group.this.name
}

output "event_source_mapping_uuid" {
  description = "UUID de la asociación entre DynamoDB Streams y Lambda."
  value       = aws_lambda_event_source_mapping.dynamodb_stream.uuid
}

output "failure_queue_name" {
  description = "Nombre de la cola que recibe eventos del stream que no pudieron procesarse."
  value       = aws_sqs_queue.stream_failures.name
}

output "failure_queue_url" {
  description = "URL de la cola de fallos de la Lambda."
  value       = aws_sqs_queue.stream_failures.url
}

output "failure_queue_arn" {
  description = "ARN de la cola de fallos de la Lambda."
  value       = aws_sqs_queue.stream_failures.arn
}