data "aws_secretsmanager_secret" "superuser" {
  count = nonsensitive(var.conn.password) == null ? 1 : 0
  name  = "${var.conn.environment}/database-server/${var.conn.server_name}/user/master"
}

data "aws_secretsmanager_secret_version" "superuser" {
  count         = nonsensitive(var.conn.password) == null ? 1 : 0
  secret_id     = data.aws_secretsmanager_secret.superuser[0].id
  version_stage = "AWSCURRENT"
}

data "aws_secretsmanager_secret" "owner" {
  name = "${var.conn.environment}/database-server/${var.conn.server_name}/user/${var.owner_id}"
}

data "aws_secretsmanager_secret_version" "owner" {
  secret_id     = data.aws_secretsmanager_secret.owner.id
  version_stage = "AWSCURRENT"
}
