# TicketFlow

Laboratorio integral de arquitectura AWS para construir una plataforma web de reservas y generación asíncrona de entradas.

## Objetivos

El proyecto integra:

- Amazon EKS y Kubernetes
- Amazon RDS PostgreSQL
- Amazon DynamoDB
- AWS Lambda
- Amazon ECS y AWS Fargate
- Amazon EC2
- Amazon SQS y S3
- Terraform
- GitHub Actions CI/CD

## Estado

Proyecto en construcción. La infraestructura se implementará incrementalmente comenzando por el backend remoto de Terraform y la red del ambiente de desarrollo.

## Estructura

- `terraform/bootstrap`: estado remoto de Terraform.
- `terraform/environments`: composición por ambiente.
- `terraform/modules`: módulos reutilizables de infraestructura.

## Seguridad

No se almacenan credenciales AWS, contraseñas, archivos de estado ni valores sensibles en el repositorio.