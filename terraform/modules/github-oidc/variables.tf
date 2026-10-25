variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Ambiente que desplegará GitHub Actions."
  type        = string
}

variable "github_repository" {
  description = "Repositorio autorizado en formato owner/repository."
  type        = string
}

variable "ecr_repository_arns" {
  description = "Repositorios ECR donde CD puede publicar imágenes."
  type        = list(string)
}

variable "ecs_cluster_name" {
  description = "Nombre del clúster ECS del worker."
  type        = string
}

variable "ecs_service_name" {
  description = "Nombre del servicio ECS del worker."
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "Rol de ejecución que CD puede asignar a una task definition."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "Rol de aplicación que CD puede asignar al worker."
  type        = string
}

variable "eks_cluster_name" {
  description = "Clúster EKS que CD puede actualizar."
  type        = string
}

variable "frontend_bucket_name" {
  description = "Bucket S3 donde CD publica el frontend."
  type        = string
}

variable "frontend_distribution_id" {
  description = "Distribución CloudFront que CD puede invalidar."
  type        = string
}

variable "lambda_function_arn" {
  description = "Función Lambda cuyo código puede actualizar CD."
  type        = string
}

variable "runtime_queue_arn" {
  description = "Cola SQS que CD puede localizar para configurar la API."
  type        = string
}
