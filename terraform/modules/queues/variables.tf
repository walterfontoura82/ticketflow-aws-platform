/*
Variables del módulo de colas.

La cola principal recibirá trabajos asíncronos, por ejemplo solicitudes para
generar entradas. La DLQ conservará los mensajes que fallen repetidamente para
poder investigarlos sin perderlos.

Valores relevantes:
- 120 segundos: tiempo inicial para que un worker procese un mensaje.
- 345600: cuatro días de retención en la cola principal.
- 1209600: catorce días en la DLQ.
- 5: después de cinco recepciones fallidas, el mensaje pasa a la DLQ.
- 20: activa long polling y reduce llamadas vacías y costos.

*/

variable "project_name" {
  description = "Nombre del proyecto utilizado en los nombres de las colas."
  type        = string
}

variable "environment" {
  description = "Ambiente al que pertenecen las colas."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Tiempo durante el cual un mensaje permanece oculto mientras un worker lo procesa."
  type        = number
  default     = 120

  validation {
    condition     = var.visibility_timeout_seconds >= 30 && var.visibility_timeout_seconds <= 43200
    error_message = "El visibility timeout debe estar entre 30 y 43200 segundos."
  }
}

variable "message_retention_seconds" {
  description = "Tiempo durante el cual SQS conserva mensajes en la cola principal."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Tiempo durante el cual la DLQ conserva mensajes fallidos."
  type        = number
  default     = 1209600
}

variable "max_receive_count" {
  description = "Cantidad de intentos permitidos antes de mover el mensaje a la DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count debe estar entre 1 y 1000."
  }
}

variable "receive_wait_time_seconds" {
  description = "Duración del long polling utilizado para reducir consultas vacías."
  type        = number
  default     = 20
}