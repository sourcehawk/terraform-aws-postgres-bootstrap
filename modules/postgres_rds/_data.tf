data "aws_secretsmanager_secret" "master" {
  name       = var.existing_user_credentials == null ? module.user_credentials[0].secret_name : module.existing_user_credentials[0].secret_name
  depends_on = [module.user_credentials, module.existing_user_credentials]
}

data "aws_secretsmanager_secret_version" "master" {
  secret_id     = data.aws_secretsmanager_secret.master.id
  version_stage = "AWSCURRENT"
}

data "aws_subnet" "db_subnets" {
  for_each = toset(var.db_subnet_ids)
  id       = each.value
}
