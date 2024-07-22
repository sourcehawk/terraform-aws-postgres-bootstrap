data "aws_secretsmanager_secret" "user" {
  name = "${var.environment}/database-server/${var.server_name}/user/${var.user_id}"
}

data "aws_secretsmanager_secret_version" "user" {
  secret_id     = data.aws_secretsmanager_secret.user.id
  version_stage = "AWSCURRENT"
}
