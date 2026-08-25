variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar y etiquetar recursos."
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente: dev, staging o prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser dev, staging o prod."
  }
}

variable "vpc_cidr" {
  description = "Bloque CIDR principal de la VPC."
  type        = string
}

variable "availability_zones" {
  description = "Zonas de disponibilidad utilizadas por la VPC."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "El laboratorio requiere exactamente dos zonas de disponibilidad."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR de las subredes públicas."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Deben definirse exactamente dos subredes públicas."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR de las subredes privadas para EKS, ECS y EC2."
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "Deben definirse exactamente dos subredes privadas de aplicación."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR de las subredes privadas reservadas para bases de datos."
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Deben definirse exactamente dos subredes privadas de base de datos."
  }
}

variable "enable_nat_gateway" {
  description = "Indica si se crea un NAT Gateway para la salida de las subredes privadas."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usa un solo NAT Gateway para reducir costos en ambientes no productivos."
  type        = bool
  default     = true
}