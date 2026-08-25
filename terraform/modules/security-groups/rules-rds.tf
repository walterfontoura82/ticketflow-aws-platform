/*
Flujos administrados por este archivo:

API EKS ──5432──────► RDS PostgreSQL
EC2 administrativa ─► RDS PostgreSQL

RDS no acepta conexiones desde Internet, desde todo el CIDR de la VPC
ni desde ECS. Sólo confía en dos security groups identificados.
*/

# La API puede iniciar conexiones PostgreSQL hacia RDS.
resource "aws_vpc_security_group_egress_rule" "eks_api_to_rds" {
  security_group_id = aws_security_group.this["eks_api"].id

  description                  = "Permite a la API iniciar conexiones PostgreSQL."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.this["rds"].id
}

# RDS acepta PostgreSQL cuando el origen tiene el SG de la API.
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_api" {
  security_group_id = aws_security_group.this["rds"].id

  description                  = "Permite PostgreSQL solamente desde la API."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.this["eks_api"].id
}

/*
La EC2 administrativa utiliza Systems Manager para crear el túnel desde
la PC. No necesita puerto 22 ni una dirección IP pública.
*/
resource "aws_vpc_security_group_egress_rule" "admin_https" {
  security_group_id = aws_security_group.this["admin_ec2"].id

  description = "Permite conexion saliente con Systems Manager."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

# La EC2 administrativa puede iniciar el túnel hacia PostgreSQL.
resource "aws_vpc_security_group_egress_rule" "admin_to_rds" {
  security_group_id = aws_security_group.this["admin_ec2"].id

  description                  = "Permite tunel administrativo hacia PostgreSQL."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.this["rds"].id
}

# RDS acepta PostgreSQL desde la identidad de red de la EC2 administrativa.
resource "aws_vpc_security_group_ingress_rule" "rds_from_admin" {
  security_group_id = aws_security_group.this["rds"].id

  description                  = "Permite PostgreSQL desde la EC2 administrativa."
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  referenced_security_group_id = aws_security_group.this["admin_ec2"].id
}
