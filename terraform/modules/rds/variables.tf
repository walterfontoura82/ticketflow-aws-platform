/*
Entradas del módulo RDS.

El módulo no recibe una contraseña. RDS generará la credencial maestra y
la almacenará en Secrets Manager mediante manage_master_user_password.
*/

variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente."
  type        = string
}

variable "database_subnet_ids" {
  description = "Subredes privadas utilizadas por el DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "RDS requiere subredes privadas en al menos dos zonas."
  }
}

variable "security_group_id" {
  description = "Security group que controla el acceso a PostgreSQL."
  type        = string
}

variable "database_name" {
  description = "Nombre de la base creada inicialmente."
  type        = string
  default     = "ticketflow"
}

variable "master_username" {
  description = "Usuario administrador inicial. La contraseña no se declara aquí."
  type        = string
  default     = "dbadmin"
}

variable "instance_class" {
  description = "Clase de instancia RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Almacenamiento inicial en GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Límite máximo del autoescalado de almacenamiento en GiB."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Crea una instancia standby en otra AZ."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Días de retención de backups automáticos."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Impide eliminar accidentalmente la instancia desde AWS."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Permite eliminar dev sin snapshot final."
  type        = bool
  default     = true
}
