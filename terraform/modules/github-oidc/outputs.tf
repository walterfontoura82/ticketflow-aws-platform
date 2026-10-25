output "provider_arn" {
  description = "ARN del proveedor OIDC de GitHub Actions."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "role_arn" {
  description = "Rol asumido por el workflow de CD."
  value       = aws_iam_role.github_actions.arn
}
