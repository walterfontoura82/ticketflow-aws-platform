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
