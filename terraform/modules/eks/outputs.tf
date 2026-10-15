output "cluster_name" {
  description = "Nombre del clúster EKS."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN del clúster EKS."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint de la API de Kubernetes."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Versión de Kubernetes."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group creado por EKS para el clúster."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Nombre del node group administrado."
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "ARN del rol IAM utilizado por los nodos."
  value       = aws_iam_role.nodes.arn
}