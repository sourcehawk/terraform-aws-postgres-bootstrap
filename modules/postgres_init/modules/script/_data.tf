data "aws_secretsmanager_secret" "user" {
  count = local.must_retrieve_user ? 1 : 0
  name  = "${var.conn.environment}/database-server/${var.conn.server_name}/user/${var.user_id}"
}

data "aws_secretsmanager_secret_version" "user" {
  count         = local.must_retrieve_user ? 1 : 0
  secret_id     = data.aws_secretsmanager_secret.user[0].id
  version_stage = "AWSCURRENT"
}

data "aws_secretsmanager_secret" "database" {
  count = local.must_retrieve_database ? 1 : 0
  name  = "${var.conn.environment}/database-server/${var.conn.server_name}/database/${var.database_id}/credentials"
}

data "aws_secretsmanager_secret_version" "database" {
  count         = local.must_retrieve_database ? 1 : 0
  secret_id     = data.aws_secretsmanager_secret.database[0].id
  version_stage = "AWSCURRENT"
}

data "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets
  name     = each.value.path
}

data "aws_secretsmanager_secret_version" "secrets" {
  for_each      = var.secrets
  secret_id     = data.aws_secretsmanager_secret.secrets[each.key].id
  version_stage = "AWSCURRENT"
}
