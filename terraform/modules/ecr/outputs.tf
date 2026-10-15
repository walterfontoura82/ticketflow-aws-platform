/*
Outputs de los repositorios ECR.

Se utilizan mapas cuya clave es el nombre lógico, por ejemplo:

repository_urls["worker"]
repository_arns["api"]
*/

output "repository_names" {
  description = "Mapa de nombres lógicos a nombres completos de repositorio."
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.name
  }
}

output "repository_urls" {
  description = "Mapa de nombres lógicos a URL de repositorio para docker push y despliegues."
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.repository_url
  }
}

output "repository_arns" {
  description = "Mapa de nombres lógicos a ARN para construir políticas IAM."
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.arn
  }
}

output "registry_id" {
  description = "ID del registro ECR, que normalmente coincide con el ID de la cuenta AWS."
  value       = values(aws_ecr_repository.this)[0].registry_id
}