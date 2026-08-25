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
