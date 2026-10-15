/*
Variables del módulo ECR.

El módulo puede crear varios repositorios usando la misma configuración de
seguridad y retención.
*/

variable "project_name" {
  description = "Nombre del proyecto utilizado como prefijo de los repositorios."
  type        = string
}

variable "environment" {
  description = "Ambiente al que pertenecen los repositorios."
  type        = string
}

variable "repository_names" {
  description = "Nombres lógicos de los repositorios que debe crear el módulo."
  type        = set(string)

  default = [
    "api",
    "worker",
  ]

  validation {
    condition = alltrue([
      for name in var.repository_names :
      can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", name))
    ])
    error_message = "Los nombres deben utilizar minúsculas y caracteres válidos para ECR."
  }
}

variable "image_tag_mutability" {
  description = "Controla si una etiqueta existente puede apuntar a otra imagen."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition = contains(
      ["MUTABLE", "IMMUTABLE"],
      var.image_tag_mutability,
    )
    error_message = "image_tag_mutability debe ser MUTABLE o IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Ejecuta el escaneo básico de vulnerabilidades al subir imágenes."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Cantidad máxima de imágenes etiquetadas que conserva cada repositorio."
  type        = number
  default     = 20

  validation {
    condition     = var.max_image_count >= 1
    error_message = "max_image_count debe ser mayor o igual a 1."
  }
}

variable "untagged_image_expiration_days" {
  description = "Días durante los que se conservan imágenes sin etiqueta."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_expiration_days >= 1
    error_message = "La expiración de imágenes sin etiqueta debe ser de al menos un día."
  }
}

variable "force_delete" {
  description = "Permite eliminar el repositorio aunque todavía contenga imágenes."
  type        = bool
  default     = false
}