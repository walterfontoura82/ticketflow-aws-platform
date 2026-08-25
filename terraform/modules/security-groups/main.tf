/*
Este módulo crea las identidades de red de cada componente.

Cada componente recibe un security group diferente para aplicar mínimo
privilegio. Por ejemplo, RDS no confía en toda la VPC: sólo aceptará
conexiones desde los security groups de la API EKS y la EC2 administrativa.

En este archivo se crean únicamente los security groups.
Las reglas ingress y egress se declaran por separado para visualizar
claramente quién inicia cada comunicación y cuál es su destino.
*/

#Esto crea siete security groups, inicialmente sin definir quién puede comunicarse con ellos.
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }



  # Este mapa define los security groups que se crearán mediante for_each.
  # La clave estable, como "rds" o "ecs_worker", permite referenciarlos
  # después desde las reglas y los outputs.
  security_groups = {
    alb = {
      name        = "alb"
      description = "Trafico publico recibido por el Application Load Balancer."
    }

    eks_api = {
      name        = "eks-api"
      description = "Workload de la API ejecutada en Amazon EKS."
    }

    ecs_worker = {
      name        = "ecs-worker"
      description = "Workers asincronicos ejecutados en ECS Fargate."
    }

    legacy_ec2 = {
      name        = "legacy-ec2"
      description = "Servicio privado de precios ejecutado en EC2."
    }

    admin_ec2 = {
      name        = "admin-ec2"
      description = "Instancia administrativa accedida mediante Systems Manager."
    }

    rds = {
      name        = "rds"
      description = "Base de datos PostgreSQL privada."
    }

    vpc_endpoints = {
      name        = "vpc-endpoints"
      description = "Endpoints privados para acceder a servicios AWS."
    }
  }
}

# for_each crea una instancia de aws_security_group por cada elemento
# del mapa local.security_groups. Todos pertenecen a la misma VPC.

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name                   = "${var.project_name}-${var.environment}-${each.value.name}-sg"
  description            = each.value.description
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.value.name}-sg"
    Role = each.value.name
  })
}
