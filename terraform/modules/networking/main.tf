#locals calcula valores internos del módulo.
#for_each crea una subred por zona de disponibilidad.
#Las públicas pueden asignar IP pública; las privadas no.
#Las etiquetas kubernetes.io/role/... ayudan a EKS a distinguir subredes para balanceadores.
#Las subredes de base quedan separadas de las cargas de aplicación.
#Activamos DNS en la VPC porque EKS, RDS y las zonas privadas dependen de resolución DNS.

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  public_subnets = {
    for index, az in var.availability_zones :
    az => var.public_subnet_cidrs[index]
  }

  private_app_subnets = {
    for index, az in var.availability_zones :
    az => var.private_app_subnet_cidrs[index]
  }

  private_db_subnets = {
    for index, az in var.availability_zones :
    az => var.private_db_subnet_cidrs[index]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                     = "${var.project_name}-${var.environment}-public-${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private_app" {
  for_each = local.private_app_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                              = "${var.project_name}-${var.environment}-private-app-${each.key}"
    Tier                              = "private-app"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_db" {
  for_each = local.private_db_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-db-${each.key}"
    Tier = "private-db"
  })
}