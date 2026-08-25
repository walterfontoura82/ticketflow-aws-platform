variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los security groups."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR de la VPC, utilizado para reglas internas controladas."
  type        = string
}

variable "api_port" {
  description = "Puerto donde escucha la API ejecutada en EKS."
  type        = number
  default     = 8080
}

variable "legacy_port" {
  description = "Puerto del servicio de precios legacy ejecutado en EC2."
  type        = number
  default     = 8081
}

variable "database_port" {
  description = "Puerto de PostgreSQL."
  type        = number
  default     = 5432
}

