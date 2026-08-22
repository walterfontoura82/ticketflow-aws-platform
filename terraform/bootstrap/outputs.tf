#Los output exponen información útil después de terraform apply; no crean recursos.

output "state_bucket_name" {
  description = "Nombre del bucket S3 utilizado para almacenar los estados de Terraform."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket S3 de estados de Terraform."
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Región donde se encuentra el bucket de estados."
  value       = aws_s3_bucket.terraform_state.region
}