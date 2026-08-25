/*
Estos outputs permiten que otros módulos encuentren RDS y su secreto.

El ARN de Secrets Manager no contiene la contraseña: sólo identifica
dónde puede recuperarla una identidad IAM autorizada.
*/

output "db_instance_id" {
  description = "Identificador de la instancia RDS."
  value       = aws_db_instance.this.id
}

output "db_address" {
  description = "Nombre DNS privado de RDS, sin incluir el puerto."
  value       = aws_db_instance.this.address
}

output "db_endpoint" {
  description = "Endpoint de RDS en formato host:puerto."
  value       = aws_db_instance.this.endpoint
}

output "db_port" {
  description = "Puerto de PostgreSQL."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Nombre de la base de datos inicial."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "ARN del secreto administrado por RDS en Secrets Manager."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "db_subnet_group_name" {
  description = "Nombre del DB subnet group."
  value       = aws_db_subnet_group.this.name
}
