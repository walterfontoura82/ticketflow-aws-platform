/*
Variables del módulo Lambda de auditoría.

El módulo recibe el ARN del stream de DynamoDB y la ruta del ZIP. Esto mantiene
separadas dos responsabilidades:

- El proceso de build genera y prueba el artefacto.
- Terraform despliega ese artefacto y configura AWS.

Decisiones iniciales:
- Python 3.12: runtime estable y compatible con nuestro código.
- 128 MB: suficiente para procesar metadatos.
- Timeout de 30 segundos.
- Logs conservados 14 días en dev.
- Hasta 100 registros por lote.
- Espera máxima de 5 segundos para agrupar eventos.

*/

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar la función y sus recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente al que pertenece la función."
  type        = string
}

variable "dynamodb_stream_arn" {
  description = "ARN del stream de DynamoDB que invocará la función."
  type        = string
}

variable "package_file" {
  description = "Ruta absoluta o relativa al paquete ZIP de la función."
  type        = string
}

variable "runtime" {
  description = "Runtime utilizado por AWS Lambda."
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Archivo y función que AWS Lambda debe invocar."
  type        = string
  default     = "handler.lambda_handler"
}

variable "memory_size" {
  description = "Memoria asignada a la función en MB."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size debe estar entre 128 y 10240 MB."
  }
}

variable "timeout_seconds" {
  description = "Tiempo máximo de ejecución de cada invocación."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 900
    error_message = "timeout_seconds debe estar entre 1 y 900 segundos."
  }
}

variable "log_retention_days" {
  description = "Cantidad de días que CloudWatch conservará los logs."
  type        = number
  default     = 14
}

variable "batch_size" {
  description = "Cantidad máxima de registros de DynamoDB por invocación."
  type        = number
  default     = 100
}

variable "maximum_batching_window_seconds" {
  description = "Tiempo máximo para reunir registros antes de invocar Lambda."
  type        = number
  default     = 5
}

/*
Límite de concurrencia reservada.

null indica que Terraform no configura concurrencia reservada. Esto permite
usar el módulo en sandboxes donde una SCP prohíbe PutFunctionConcurrency.

En una cuenta de producción sin esa restricción se puede establecer, por
ejemplo, el valor 2.
*/
variable "reserved_concurrent_executions" {
  description = "Concurrencia reservada de Lambda; null deja el valor sin administrar."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition = (
      var.reserved_concurrent_executions == null ||
      var.reserved_concurrent_executions >= 0
    )
    error_message = "La concurrencia reservada debe ser null o un número mayor o igual a cero."
  }
}