output "bucket_name" {
  description = "Bucket privado que almacena el frontend."
  value       = aws_s3_bucket.this.id
}

output "distribution_id" {
  description = "ID de la distribución CloudFront."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "Dominio HTTPS público de TicketFlow."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "website_url" {
  description = "URL pública del frontend."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}