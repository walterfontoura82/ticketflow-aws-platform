/*
Este archivo no contiene la implementación de la VPC. Sólo instancia el módulo y le entrega los valores de dev.
Así podremos reutilizar el mismo módulo desde staging y prod con CIDR y políticas diferentes.

*/
module "networking" {
  source = "../../modules/networking"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
}

/*
Security groups depende de networking porque necesita:

- La VPC donde se crearán los grupos.
- El CIDR utilizado por la regla de VPC Endpoints.

Las referencias module.networking.* crean la dependencia automáticamente.
*/
module "security_groups" {
  source = "../../modules/security-groups"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  vpc_cidr_block = module.networking.vpc_cidr_block
}


/*
RDS depende de dos módulos:

- networking entrega las subredes privadas de base de datos.
- security_groups entrega la identidad de red que permite PostgreSQL
  solamente desde EKS y la EC2 administrativa.

Estas referencias crean las dependencias automáticamente.
*/

/*

networking.private_db_subnet_ids ─┐
                                  ├──► module.rds
security_groups.rds_sg_id ────────┘

*/
module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  database_subnet_ids = module.networking.private_db_subnet_ids
  security_group_id   = module.security_groups.rds_security_group_id

  # Configuración económica para el laboratorio.
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

/*
Instancia administrativa privada.

Se ubica en la primera subnet privada de aplicaciones y no recibe una IP
pública. La administración se realiza mediante AWS Systems Manager (SSM),
sin abrir el puerto 22 ni utilizar claves SSH.

Su Security Group permite:

- Salida HTTPS para comunicarse con Systems Manager.
- Salida al puerto 5432 del Security Group de RDS.

Esta instancia servirá como puente para acceder desde nuestra PC al RDS
privado mediante un túnel de Session Manager.
*/
module "ec2_admin" {
  source = "../../modules/ec2-admin"

  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.networking.private_app_subnet_ids[0]
  security_group_id = module.security_groups.admin_ec2_security_group_id

  instance_type    = "t3.micro"
  root_volume_size = 8
}

/*
Tabla DynamoDB principal del ambiente dev.

El ambiente entrega los valores generales al módulo y decide las protecciones
que corresponden a este entorno.

En producción deletion_protection_enabled debería ser true. En este sandbox
queda false para permitir destruir la infraestructura cuando expire.

Flujo:
var.project_name y var.environment
  → module.dynamodb
  → variables del módulo
  → nombre de aws_dynamodb_table.this
  → ticketflow-dev-application
source indica dónde está el módulo local. Terraform leerá sus archivos main.tf, variables.tf y outputs.tf como una unidad.

*/
module "dynamodb" {
  source = "../../modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment

  point_in_time_recovery_enabled = true
  deletion_protection_enabled    = false
}

/*
Colas de procesamiento asíncrono.

La API enviará trabajos a la cola principal y los workers de ECS/Fargate los
consumirán. Los mensajes que fallen cinco veces pasarán a la DLQ.
*/
module "queues" {
  source = "../../modules/queues"

  project_name = var.project_name
  environment  = var.environment

  visibility_timeout_seconds    = 120
  message_retention_seconds     = 345600
  dlq_message_retention_seconds = 1209600
  max_receive_count             = 5
  receive_wait_time_seconds     = 20
}

/*
Lambda de auditoría de DynamoDB.

La dependencia se forma automáticamente porque el módulo Lambda recibe el ARN
del stream producido por module.dynamodb.

abspath convierte la ruta del ZIP en una ruta absoluta para evitar diferencias
según el directorio desde el que se ejecute Terraform.
*/
module "lambda_audit" {
  source = "../../modules/lambda"

  project_name = var.project_name
  environment  = var.environment

  dynamodb_stream_arn = module.dynamodb.stream_arn

  package_file = abspath(
    "${path.root}/../../../services/lambda-audit/build/lambda-audit.zip"
  )

  runtime         = "python3.12"
  handler         = "handler.lambda_handler"
  memory_size     = 128
  timeout_seconds = 30

  log_retention_days              = 14
  batch_size                      = 100
  maximum_batching_window_seconds = 5
}

/*
Repositorios privados de imágenes.

API se utilizará posteriormente desde EKS.
Worker se utilizará desde ECS/Fargate.

force_delete queda habilitado solamente porque dev es un sandbox descartable.
En producción debe ser false para evitar borrar repositorios con imágenes.
*/
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_names = [
    "api",
    "worker",
  ]

  image_tag_mutability           = "IMMUTABLE"
  scan_on_push                   = true
  max_image_count                = 20
  untagged_image_expiration_days = 7
  force_delete                   = true
}
module "ecs_workers" {
  source = "../../modules/ecs-workers"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  container_image = "${module.ecr.repository_urls["worker"]}:${var.worker_image_tag}"

  private_subnet_ids = module.networking.private_app_subnet_ids
  security_group_id  = module.security_groups.ecs_worker_security_group_id

  queue_arn = module.queues.ticket_generation_queue_arn
  queue_url = module.queues.ticket_generation_queue_url

  dynamodb_table_arn  = module.dynamodb.table_arn
  dynamodb_table_name = module.dynamodb.table_name
}
module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  kubernetes_version = "1.36"

  private_subnet_ids  = module.networking.private_app_subnet_ids
  public_access_cidrs = var.eks_public_access_cidrs

  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
}