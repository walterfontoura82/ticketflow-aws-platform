# Permite PostgreSQL desde los pods que utilizan la interfaz de red
# y el Security Group administrado del clúster EKS.
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_cluster" {
  security_group_id = module.security_groups.rds_security_group_id

  description                  = "Permite PostgreSQL desde el cluster EKS."
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = module.eks.cluster_security_group_id
}