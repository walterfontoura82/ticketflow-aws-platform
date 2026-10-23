variable "aws_region" {
  description = "Región AWS del ambiente."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
  default     = "ticketflow"
}

variable "environment" {
  description = "Nombre del ambiente."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Este root module administra únicamente el ambiente dev."
  }
}

variable "vpc_cidr" {
  description = "CIDR principal de la VPC de desarrollo."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad utilizadas en desarrollo."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR de las subredes públicas."
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR de las subredes privadas de aplicación."
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR de las subredes privadas de base de datos."
  type        = list(string)
  default     = ["10.10.20.0/24", "10.10.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Habilita salida a Internet desde las subredes privadas de aplicación."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usa un único NAT Gateway para reducir costos en dev."
  type        = bool
  default     = true
}
variable "worker_image_tag" {
  description = "Tag inmutable de la imagen del worker."
  type        = string
  default     = "15d1ac428489-amd64"
}
variable "eks_public_access_cidrs" {
  description = "CIDR autorizados para acceder al endpoint público de EKS."
  type        = list(string)
  default     = ["45.191.81.233/32"]
}
