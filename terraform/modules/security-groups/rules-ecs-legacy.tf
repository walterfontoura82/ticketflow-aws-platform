/*
Flujos administrados por este archivo:

ECS/Fargate ──443──► SQS, S3, DynamoDB, ECR y otros servicios AWS
ECS/Fargate ──8081─► Servicio de precios legacy en EC2
EC2 legacy ──443───► Servicios AWS y actualizaciones

El worker no necesita ingress: consulta SQS e inicia el procesamiento.
La EC2 legacy sólo recibe solicitudes provenientes del SG de ECS.
*/

# El worker puede iniciar conexiones HTTPS.
resource "aws_vpc_security_group_egress_rule" "ecs_worker_https" {
  security_group_id = aws_security_group.this["ecs_worker"].id

  description = "Permite HTTPS saliente desde ECS Fargate."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

# ECS puede consultar únicamente el puerto de aplicación del servicio legacy.
resource "aws_vpc_security_group_egress_rule" "ecs_worker_to_legacy" {
  security_group_id = aws_security_group.this["ecs_worker"].id

  description                  = "Permite al worker consultar el servicio legacy."
  ip_protocol                  = "tcp"
  from_port                    = var.legacy_port
  to_port                      = var.legacy_port
  referenced_security_group_id = aws_security_group.this["legacy_ec2"].id
}

# La EC2 legacy sólo recibe solicitudes desde tareas con el SG de ECS.
resource "aws_vpc_security_group_ingress_rule" "legacy_from_ecs_worker" {
  security_group_id = aws_security_group.this["legacy_ec2"].id

  description                  = "Permite solicitudes solamente desde ECS."
  ip_protocol                  = "tcp"
  from_port                    = var.legacy_port
  to_port                      = var.legacy_port
  referenced_security_group_id = aws_security_group.this["ecs_worker"].id
}

# La EC2 legacy puede utilizar HTTPS para AWS y actualizaciones.
resource "aws_vpc_security_group_egress_rule" "legacy_https" {
  security_group_id = aws_security_group.this["legacy_ec2"].id

  description = "Permite HTTPS para servicios AWS y actualizaciones."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}
