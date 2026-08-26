/*
Este archivo no contiene la implementación de la VPC. Sólo instancia el módulo y le entrega los valores de dev.
Así podremos reutilizar el mismo módulo desde staging y prod con CIDR y políticas diferentes.

*/
module "networking" {
  source = "../../modules/networking"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
}

/*
Security groups depende de networking porque necesita:

- La VPC donde se crearán los grupos.
- El CIDR utilizado por la regla de VPC Endpoints.

Las referencias module.networking.* crean la dependencia automáticamente.
*/
module "security_groups" {
  source = "../../modules/security-groups"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  vpc_cidr_block = module.networking.vpc_cidr_block
}


/*
RDS depende de dos módulos:

- networking entrega las subredes privadas de base de datos.
- security_groups entrega la identidad de red que permite PostgreSQL
  solamente desde EKS y la EC2 administrativa.

Estas referencias crean las dependencias automáticamente.
*/

/*

networking.private_db_subnet_ids ─┐
                                  ├──► module.rds
security_groups.rds_sg_id ────────┘

*/
module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  database_subnet_ids = module.networking.private_db_subnet_ids
  security_group_id   = module.security_groups.rds_security_group_id

  # Configuración económica para el laboratorio.
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

/*
Instancia administrativa privada.

Se ubica en la primera subnet privada de aplicaciones y no recibe una IP
pública. La administración se realiza mediante AWS Systems Manager (SSM),
sin abrir el puerto 22 ni utilizar claves SSH.

Su Security Group permite:

- Salida HTTPS para comunicarse con Systems Manager.
- Salida al puerto 5432 del Security Group de RDS.

Esta instancia servirá como puente para acceder desde nuestra PC al RDS
privado mediante un túnel de Session Manager.
*/
module "ec2_admin" {
  source = "../../modules/ec2-admin"

  project_name      = var.project_name
  environment       = var.environment
  subnet_id         = module.networking.private_app_subnet_ids[0]
  security_group_id = module.security_groups.admin_ec2_security_group_id

  instance_type    = "t3.micro"
  root_volume_size = 8
}