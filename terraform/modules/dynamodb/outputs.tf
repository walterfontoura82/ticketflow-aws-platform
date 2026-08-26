/*
Outputs del módulo DynamoDB.

El nombre y ARN se utilizarán posteriormente para configurar las aplicaciones
y construir políticas IAM de mínimo privilegio.

No se exponen credenciales porque DynamoDB autentica las solicitudes mediante
roles y políticas IAM.
*/

output "table_name" {
  description = "Nombre de la tabla DynamoDB principal."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN de la tabla, utilizado principalmente en políticas IAM."
  value       = aws_dynamodb_table.this.arn
}

output "table_id" {
  description = "Identificador de la tabla DynamoDB."
  value       = aws_dynamodb_table.this.id
}

output "gsi1_name" {
  description = "Nombre del índice secundario global principal."
  value       = "GSI1"
}