# Datos generales usados para nombrar y etiquetar recursos.
variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se ejecutará el worker."
  type        = string
}

variable "aws_region" {
  description = "Región AWS utilizada por el contenedor."
  type        = string
}

# Imagen inmutable publicada en ECR.
variable "container_image" {
  description = "URI completa de la imagen, incluyendo su tag inmutable."
  type        = string
}

# Fargate ejecutará las tareas en subredes privadas y sin IP pública.
variable "private_subnet_ids" {
  description = "Subredes privadas donde se ejecutarán las tareas."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group asignado a las tareas ECS."
  type        = string
}

# Cola consumida por el worker.
variable "queue_arn" {
  description = "ARN de la cola SQS que procesará el worker."
  type        = string
}

variable "queue_url" {
  description = "URL de la cola SQS que recibirá el contenedor."
  type        = string
}

# Capacidad inicial del contenedor.
variable "task_cpu" {
  description = "CPU de cada tarea Fargate."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memoria en MiB de cada tarea Fargate."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Cantidad inicial de tareas del worker."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch."
  type        = number
  default     = 14
}
variable "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB que actualizará el worker."
  type        = string
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla enviado al contenedor."
  type        = string
}
variable "worker_image_tag" {
  description = "Tag inmutable de la imagen del worker publicada en ECR."
  type        = string
  default     = "15d1ac428489-amd64"
}
