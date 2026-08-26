/*
El instance ID se utiliza como target de Systems Manager.

La IP privada se expone para diagnóstico, pero no será accesible directamente
desde Internet.
*/

output "instance_id" {
  description = "ID de la instancia administrativa."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Dirección IP privada de la instancia."
  value       = aws_instance.this.private_ip
}

output "iam_role_arn" {
  description = "ARN del rol IAM utilizado por la instancia."
  value       = aws_iam_role.this.arn
}
