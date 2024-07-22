output "secret_name" {
  description = "Name of the secret containing the database connection credentials"
  value       = "${var.environment}/database-server/${var.server_name}/database/${local.id}/credentials"
}

output "id" {
  description = "The id of the database the credentials were created for. Used in secret name."
  value       = local.id
}
