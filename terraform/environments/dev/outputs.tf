output "vpc_id" {
  description = "ID de la VPC del ambiente dev."
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR de la VPC del ambiente dev."
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs de las subredes privadas de aplicación."
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs de las subredes privadas de base de datos."
  value       = module.networking.private_db_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateway del ambiente dev."
  value       = module.networking.nat_gateway_ids
}

/*
Security groups disponibles para los módulos de aplicación.
Estos outputs también permiten verificarlos mediante terraform output.
*/

output "alb_security_group_id" {
  description = "Security group del ALB."
  value       = module.security_groups.alb_security_group_id
}

output "eks_api_security_group_id" {
  description = "Security group de la API en EKS."
  value       = module.security_groups.eks_api_security_group_id
}

output "ecs_worker_security_group_id" {
  description = "Security group del worker ECS Fargate."
  value       = module.security_groups.ecs_worker_security_group_id
}

output "legacy_ec2_security_group_id" {
  description = "Security group de la EC2 legacy."
  value       = module.security_groups.legacy_ec2_security_group_id
}

output "admin_ec2_security_group_id" {
  description = "Security group de la EC2 administrativa."
  value       = module.security_groups.admin_ec2_security_group_id
}

output "rds_security_group_id" {
  description = "Security group de RDS."
  value       = module.security_groups.rds_security_group_id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group de VPC Interface Endpoints."
  value       = module.security_groups.vpc_endpoints_security_group_id
}


/*
Información de RDS visible desde el root module.

El secreto se expone únicamente como ARN. El valor de la contraseña
permanece almacenado en Secrets Manager.
*/

output "rds_instance_id" {
  description = "Identificador de la instancia RDS."
  value       = module.rds.db_instance_id
}

output "rds_address" {
  description = "Nombre DNS privado de RDS."
  value       = module.rds.db_address
}

output "rds_endpoint" {
  description = "Endpoint privado de PostgreSQL."
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "Puerto de PostgreSQL."
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "Nombre de la base de datos."
  value       = module.rds.database_name
}

output "rds_master_user_secret_arn" {
  description = "ARN del secreto maestro administrado por RDS."
  value       = module.rds.master_user_secret_arn
}

/*
Datos de la instancia administrativa.

El instance ID será necesario para iniciar sesiones y túneles mediante
AWS Systems Manager. La IP privada se muestra solamente como referencia:
no se utiliza para conectarnos directamente desde Internet.

aws_instance.this.id
  → output.instance_id del módulo ec2-admin
  → module.ec2_admin.instance_id
  → output.admin_ec2_instance_id del ambiente dev

*/

output "admin_ec2_instance_id" {
  description = "ID de la instancia EC2 administrativa utilizada como puente SSM."
  value       = module.ec2_admin.instance_id
}

output "admin_ec2_private_ip" {
  description = "Dirección IP privada de la instancia administrativa."
  value       = module.ec2_admin.private_ip
}

output "admin_ec2_iam_role_arn" {
  description = "ARN del rol IAM asociado con la instancia administrativa."
  value       = module.ec2_admin.iam_role_arn
}

/*
Información de DynamoDB expuesta por el ambiente dev.

Estos valores permiten consultar la tabla y crear posteriormente políticas IAM
sin repetir nombres o ARN manualmente.
*/

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB principal de dev."
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB principal de dev."
  value       = module.dynamodb.table_arn
}

output "dynamodb_table_id" {
  description = "Identificador de la tabla DynamoDB principal de dev."
  value       = module.dynamodb.table_id
}

output "dynamodb_gsi1_name" {
  description = "Nombre del índice secundario global de la tabla."
  value       = module.dynamodb.gsi1_name
}

/*
Información de las colas SQS del ambiente dev.

Las aplicaciones consumirán las URL. Los módulos IAM y de observabilidad
utilizarán los ARN y nombres.

aws_sqs_queue.ticket_generation.url
  → output del módulo queues
  → module.queues.ticket_generation_queue_url
  → output del ambiente dev

*/

output "ticket_generation_queue_name" {
  description = "Nombre de la cola principal de generación de entradas."
  value       = module.queues.ticket_generation_queue_name
}

output "ticket_generation_queue_url" {
  description = "URL de la cola principal de generación de entradas."
  value       = module.queues.ticket_generation_queue_url
}

output "ticket_generation_queue_arn" {
  description = "ARN de la cola principal de generación de entradas."
  value       = module.queues.ticket_generation_queue_arn
}

output "ticket_generation_dlq_name" {
  description = "Nombre de la Dead Letter Queue."
  value       = module.queues.dead_letter_queue_name
}

output "ticket_generation_dlq_url" {
  description = "URL de la Dead Letter Queue."
  value       = module.queues.dead_letter_queue_url
}

output "ticket_generation_dlq_arn" {
  description = "ARN de la Dead Letter Queue."
  value       = module.queues.dead_letter_queue_arn
}

/*
DynamoDB Streams y Lambda de auditoría.

Estos valores permiten verificar el flujo, consultar logs, probar la función y
crear alarmas posteriormente.
*/

output "dynamodb_stream_arn" {
  description = "ARN del stream de la tabla DynamoDB."
  value       = module.dynamodb.stream_arn
}

output "dynamodb_stream_label" {
  description = "Etiqueta de la versión activa del stream."
  value       = module.dynamodb.stream_label
}

output "lambda_audit_function_name" {
  description = "Nombre de la función Lambda de auditoría."
  value       = module.lambda_audit.function_name
}

output "lambda_audit_function_arn" {
  description = "ARN de la función Lambda de auditoría."
  value       = module.lambda_audit.function_arn
}

output "lambda_audit_execution_role_arn" {
  description = "ARN del rol IAM de ejecución de la Lambda."
  value       = module.lambda_audit.execution_role_arn
}

output "lambda_audit_log_group_name" {
  description = "Nombre del grupo de logs de la Lambda."
  value       = module.lambda_audit.log_group_name
}

output "lambda_audit_event_source_mapping_uuid" {
  description = "UUID de la asociación entre DynamoDB Streams y Lambda."
  value       = module.lambda_audit.event_source_mapping_uuid
}

output "lambda_audit_failure_queue_name" {
  description = "Nombre de la cola de eventos fallidos de la Lambda."
  value       = module.lambda_audit.failure_queue_name
}

output "lambda_audit_failure_queue_url" {
  description = "URL de la cola de eventos fallidos de la Lambda."
  value       = module.lambda_audit.failure_queue_url
}

output "lambda_audit_failure_queue_arn" {
  description = "ARN de la cola de eventos fallidos de la Lambda."
  value       = module.lambda_audit.failure_queue_arn
}

/*
Repositorios ECR del ambiente dev.

Las URLs se usarán para publicar imágenes y referenciarlas desde ECS/EKS.
Los ARN se utilizarán en políticas IAM.
*/

output "ecr_repository_names" {
  description = "Mapa de nombres lógicos a nombres completos de repositorio ECR."
  value       = module.ecr.repository_names
}

output "ecr_repository_urls" {
  description = "Mapa de nombres lógicos a URLs de repositorio ECR."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Mapa de nombres lógicos a ARN de repositorio ECR."
  value       = module.ecr.repository_arns
}

output "ecr_registry_id" {
  description = "ID del registro ECR del ambiente."
  value       = module.ecr.registry_id
}