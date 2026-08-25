/*

Terraform solicita crear RDS
          │
          ▼
RDS genera una contraseña
          │
          ▼
Secrets Manager guarda el secreto
          │
          ▼
Terraform recibe sólo el ARN de referencia

*/

/*
El DB subnet group indica en qué subredes privadas puede colocar RDS
la instancia primaria y, cuando se habilite Multi-AZ, su standby.

Recibe las subredes desde module.networking.private_db_subnet_ids.
*/
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

/*
Instancia PostgreSQL privada.

Decisiones principales:
- No tiene IP pública.
- Sólo utiliza el security group específico de RDS.
- El almacenamiento se cifra y puede crecer automáticamente.
- RDS genera la contraseña maestra y la guarda en Secrets Manager.
- No se declara engine_version para permitir que AWS seleccione una versión
  soportada; más adelante fijaremos una versión probada para producción.
*/
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username

  # Evita guardar una contraseña escrita por nosotros en código o tfvars.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  multi_az                 = var.multi_az
  backup_retention_period  = var.backup_retention_period
  copy_tags_to_snapshot    = true
  delete_automated_backups = true

  auto_minor_version_upgrade = true
  apply_immediately          = true

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
