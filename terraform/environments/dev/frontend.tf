# Localiza automáticamente el ALB creado por Kubernetes.
data "aws_lb" "ticketflow_api" {
  tags = {
    "ingress.k8s.aws/stack" = "ticketflow/ticketflow-api"
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
  }
}

module "frontend" {
  source = "../../modules/frontend"

  project_name = var.project_name
  environment  = var.environment

  alb_dns_name  = data.aws_lb.ticketflow_api.dns_name
  force_destroy = true
}