output "rds_instance" {
  description = "The created RDS instance"
  value       = aws_db_instance.this
}

output "database_access_security_group_id" {
  description = "The ID of a security group that allows network traffic between the database and another AWS resource when attached to the resource. Note that this is only needed if the resource is not within the allowed CIDRs."
  value       = aws_security_group.access.id
}

output "database_security_group_id" {
  description = "The ID of the security group attached to the RDS instance."
  value       = aws_security_group.this.id
}

output "database_credentials_secret_name" {
  description = "The name of the secret containing the database credentials."
  value       = module.database_credentials.secret_name
}

output "user_credentials_secret_name" {
  description = "The name of the secret containing the user credentials."
  value       = var.existing_user_credentials == null ? module.user_credentials[0].secret_name : module.existing_user_credentials[0].secret_name
}
