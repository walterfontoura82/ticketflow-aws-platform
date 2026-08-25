/*
Los outputs publican los IDs creados por este módulo.

Los módulos consumidores no necesitan conocer cómo se construyó cada SG.
Sólo reciben el ID correspondiente, lo que reduce el acoplamiento.
*/

output "alb_security_group_id" {
  description = "Security group del Application Load Balancer."
  value       = aws_security_group.this["alb"].id
}

output "eks_api_security_group_id" {
  description = "Security group del workload API ejecutado en EKS."
  value       = aws_security_group.this["eks_api"].id
}

output "ecs_worker_security_group_id" {
  description = "Security group de las tareas ECS Fargate."
  value       = aws_security_group.this["ecs_worker"].id
}

output "legacy_ec2_security_group_id" {
  description = "Security group de la instancia EC2 legacy."
  value       = aws_security_group.this["legacy_ec2"].id
}

output "admin_ec2_security_group_id" {
  description = "Security group de la instancia EC2 administrativa."
  value       = aws_security_group.this["admin_ec2"].id
}

output "rds_security_group_id" {
  description = "Security group de RDS PostgreSQL."
  value       = aws_security_group.this["rds"].id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group utilizado por VPC Interface Endpoints."
  value       = aws_security_group.this["vpc_endpoints"].id
}
