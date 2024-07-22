data "aws_secretsmanager_secret" "superuser" {
  count = sensitive(var.conn.password) == null ? 1 : 0
  name  = "${var.conn.environment}/database-server/${var.conn.server_name}/user/master"
}

data "aws_secretsmanager_secret_version" "superuser" {
  count         = sensitive(var.conn.password) == null ? 1 : 0
  secret_id     = data.aws_secretsmanager_secret.superuser[0].id
  version_stage = "AWSCURRENT"
}

data "aws_secretsmanager_secret" "user" {
  name       = module.user_credentials.secret_name
  depends_on = [module.user_credentials]
}

data "aws_secretsmanager_secret_version" "user" {
  secret_id     = data.aws_secretsmanager_secret.user.id
  version_stage = "AWSCURRENT"
  depends_on    = [module.user_credentials]
}
