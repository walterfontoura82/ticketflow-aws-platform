/*
Flujo administrado por este archivo:

Internet ──80/443──► ALB ──8080──► API en EKS
API EKS ──443────────────────────► Servicios AWS o Internet

El puerto 80 se permite únicamente para poder redireccionar HTTP a HTTPS.
El ALB no puede acceder a cualquier recurso de la VPC: sólo al security
group de la API y únicamente en el puerto definido por var.api_port.
*/

/*
Egress del origen ALB
        +
Ingress del destino EKS
*/

# Permite recibir HTTP público en el ALB para redireccionarlo a HTTPS.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.this["alb"].id

  description = "Permite HTTP publico para redireccion a HTTPS."
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

# Permite recibir la aplicación públicamente mediante HTTPS.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.this["alb"].id

  description = "Permite HTTPS publico."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

# El ALB sólo puede iniciar conexiones hacia la API en su puerto.
resource "aws_vpc_security_group_egress_rule" "alb_to_eks_api" {
  security_group_id = aws_security_group.this["alb"].id

  description                  = "Permite al ALB comunicarse con la API."
  ip_protocol                  = "tcp"
  from_port                    = var.api_port
  to_port                      = var.api_port
  referenced_security_group_id = aws_security_group.this["eks_api"].id
}

# La API sólo recibe tráfico de aplicación que provenga del SG del ALB.
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_alb" {
  security_group_id = aws_security_group.this["eks_api"].id

  description                  = "Permite trafico recibido desde el ALB."
  ip_protocol                  = "tcp"
  from_port                    = var.api_port
  to_port                      = var.api_port
  referenced_security_group_id = aws_security_group.this["alb"].id
}

# La API puede iniciar HTTPS para Secrets Manager, SQS y otros servicios.
# La ruta decidirá si el tráfico utiliza NAT o un VPC Endpoint.
resource "aws_vpc_security_group_egress_rule" "eks_api_https" {
  security_group_id = aws_security_group.this["eks_api"].id

  description = "Permite HTTPS saliente desde la API."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}
