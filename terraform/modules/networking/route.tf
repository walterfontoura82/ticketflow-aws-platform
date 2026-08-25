/*

Subred pública
└── 0.0.0.0/0 → Internet Gateway

Subred privada de aplicación
└── 0.0.0.0/0 → NAT Gateway

Subred privada de base de datos
└── sin ruta predeterminada a Internet
Las subredes de base pueden comunicarse dentro de la VPC mediante la ruta local, creada automáticamente por AWS, pero no tienen salida directa a Internet.

*/

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  for_each = local.private_app_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-app-rt-${each.key}"
    Tier = "private-app"
  })
}

resource "aws_route" "private_app_nat" {
  for_each = var.enable_nat_gateway ? local.private_app_subnets : {}

  route_table_id         = aws_route_table.private_app[each.key].id
  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.this[
    var.single_nat_gateway ? var.availability_zones[0] : each.key
  ].id
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table" "private_db" {
  for_each = local.private_db_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-db-rt-${each.key}"
    Tier = "private-db"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}