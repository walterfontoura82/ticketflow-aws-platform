/* Qué hace:
- Selecciona sólo la primera AZ cuando single_nat_gateway = true.
- Reserva una Elastic IP.
- Crea el NAT en la subred pública de esa AZ.
- No crea nada si enable_nat_gateway = false.
- Declara que el Internet Gateway debe existir primero.
*/

locals {
  nat_gateway_zones = var.enable_nat_gateway ? (
    var.single_nat_gateway
    ? toset([var.availability_zones[0]])
    : toset(var.availability_zones)
  ) : toset([])
}

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_zones

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_zones

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-${each.key}"
  })
}