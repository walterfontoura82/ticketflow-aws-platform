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
