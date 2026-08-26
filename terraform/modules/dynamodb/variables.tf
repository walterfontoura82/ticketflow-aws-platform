/*
Variables del módulo DynamoDB.

La tabla utilizará un diseño flexible con claves genéricas PK y SK. Esto
permite almacenar distintos tipos de registros sin crear una tabla por cada
entidad.

En desarrollo usaremos capacidad bajo demanda para no reservar capacidad fija.

Por qué estas decisiones:
- PAY_PER_REQUEST se definirá dentro del módulo: en el laboratorio pagamos solamente por uso.
- point_in_time_recovery_enabled = true permite recuperar información ante escrituras o borrados accidentales.
- La protección contra borrado queda desactivada en dev para poder destruir el laboratorio; en prod deberá estar activada.
- Ninguna variable contiene secretos: DynamoDB utiliza permisos IAM, no usuario y contraseña.

*/

variable "project_name" {
  description = "Nombre del proyecto utilizado para identificar la tabla."
  type        = string
}

variable "environment" {
  description = "Ambiente al que pertenece la tabla, por ejemplo dev."
  type        = string
}

variable "point_in_time_recovery_enabled" {
  description = "Activa la recuperación de la tabla a un punto específico del tiempo."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Impide borrar accidentalmente la tabla desde AWS o Terraform."
  type        = bool
  default     = false
}