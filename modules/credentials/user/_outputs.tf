output "secret_name" {
  description = "Name of the secret containing the users credentials"
  value       = "${var.environment}/database-server/${var.server_name}/user/${local.id}"
}

output "id" {
  description = "The id of the user the credentials were created for. Used in secret name."
  value       = local.id
}
