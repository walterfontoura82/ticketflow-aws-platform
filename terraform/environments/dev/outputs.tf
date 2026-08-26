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