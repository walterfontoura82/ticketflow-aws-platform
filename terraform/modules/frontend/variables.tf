variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Ambiente del frontend."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS del Application Load Balancer que publica la API."
  type        = string
}

variable "force_destroy" {
  description = "Permite eliminar el bucket con objetos; solo para sandbox."
  type        = bool
  default     = false
}