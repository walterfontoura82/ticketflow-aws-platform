variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Ambiente del clúster."
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes administrada por EKS."
  type        = string
  default     = "1.36"
}

variable "private_subnet_ids" {
  description = "Subredes privadas utilizadas por EKS y sus nodos."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requiere subredes en al menos dos zonas de disponibilidad."
  }
}

variable "public_access_cidrs" {
  description = "CIDR autorizados para acceder al endpoint público de Kubernetes."
  type        = list(string)
}

variable "node_instance_types" {
  description = "Tipos de instancia del node group administrado."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Cantidad deseada de nodos."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Cantidad mínima de nodos."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Cantidad máxima de nodos."
  type        = number
  default     = 3
}
