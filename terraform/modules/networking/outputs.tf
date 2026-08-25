/*
Estos outputs serán consumidos posteriormente por:
- EKS y ECS: subredes privadas de aplicación.
- RDS: subredes privadas de base.
- ALB: subredes públicas o privadas, según su función.
- VPC Endpoints: tablas de rutas privadas.

*/

output "vpc_id" {
  description = "ID de la VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR principal de la VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas ordenados por zona."
  value = [
    for az in var.availability_zones :
    aws_subnet.public[az].id
  ]
}

output "private_app_subnet_ids" {
  description = "IDs de las subredes privadas de aplicación ordenados por zona."
  value = [
    for az in var.availability_zones :
    aws_subnet.private_app[az].id
  ]
}

output "private_db_subnet_ids" {
  description = "IDs de las subredes privadas de base de datos ordenados por zona."
  value = [
    for az in var.availability_zones :
    aws_subnet.private_db[az].id
  ]
}

output "public_route_table_id" {
  description = "ID de la tabla de rutas pública."
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "IDs de las tablas de rutas privadas de aplicación."
  value = [
    for az in var.availability_zones :
    aws_route_table.private_app[az].id
  ]
}

output "private_db_route_table_ids" {
  description = "IDs de las tablas de rutas privadas de base de datos."
  value = [
    for az in var.availability_zones :
    aws_route_table.private_db[az].id
  ]
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateway creados."
  value       = [for nat in aws_nat_gateway.this : nat.id]
}