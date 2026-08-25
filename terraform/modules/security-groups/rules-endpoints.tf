/*
Los Interface Endpoints crean interfaces de red privadas dentro de la VPC.

Esta regla permite que recursos internos contacten esas interfaces mediante
HTTPS. Inicialmente usamos el CIDR completo de la VPC porque distintos
workloads necesitarán endpoints. Más adelante podremos restringir el origen
a security groups concretos según los endpoints realmente creados.
*/

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  security_group_id = aws_security_group.this["vpc_endpoints"].id

  description = "Permite HTTPS desde recursos internos de la VPC."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = var.vpc_cidr_block
}
