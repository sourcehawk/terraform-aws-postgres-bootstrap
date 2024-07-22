terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/docker-init"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment          = "test"
  server_name          = "docker-init"
  maintenance_database = "postgres"
  maintenance_user     = "postgres"
  database_port        = 10565
  database_host        = "localhost"
}

# Create master user credentials
module "user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  name                    = local.maintenance_user
  master_user             = true
  recovery_window_in_days = 0
}

# Create master database credentials
module "database_credentials" {
  source = "../../modules/credentials/database"

  server_name     = local.server_name
  environment     = local.environment
  database        = local.maintenance_database
  host            = local.database_host
  port            = local.database_port
  engine          = "postgres"
  user_id         = module.user_credentials.id # "master"
  user_role       = "owner"
  master_database = true

  # We must depend on the user_credentials module because the user credentials are fetched from Secrets Manager
  depends_on = [module.user_credentials]
}

# Retrieve the superuser credentials for the docker setup
data "aws_secretsmanager_secret" "user_credentials" {
  name       = module.user_credentials.secret_name
  depends_on = [module.user_credentials]
}

data "aws_secretsmanager_secret_version" "user_credentials" {
  secret_id     = data.aws_secretsmanager_secret.user_credentials.id
  version_stage = "AWSCURRENT"
  depends_on    = [module.user_credentials]
}

resource "null_resource" "postgres_docker" {
  provisioner "local-exec" {
    environment = {
      "PG_USER"     = local.maintenance_user
      "PG_DATABASE" = local.maintenance_database
      "PG_PORT"     = local.database_port
      # If you declare it here, it will be stored in the state file, you can move it inside the template to prevent that.
      "PG_PASSWORD" = sensitive(jsondecode(data.aws_secretsmanager_secret_version.user_credentials.secret_string)["password"])
    }
    quiet   = true
    command = <<EOT
    set -e
    
    docker run --name test-local-init \
    --restart no \
    --detach \
    -e POSTGRES_USER="$PG_USER" \
    -e POSTGRES_PASSWORD="$PG_PASSWORD" \
    -e POSTGRES_DB="$PG_DATABASE" \
    -p "$PG_PORT:5432" \
    postgres:15

    sleep 5
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "(docker stop test-local-init && docker rm test-local-init) || true"
  }

  depends_on = [module.user_credentials]
}

module "postgres_init" {
  source = "../../modules/postgres_init"

  conn = {
    host                 = local.database_host
    port                 = local.database_port
    engine               = "postgres"
    maintenance_user     = local.maintenance_user
    maintenance_database = local.maintenance_database
    environment          = local.environment
    server_name          = local.server_name
  }

  users = [
    { id = "user_for_db_1", name = "user_1", password = "foobarbaz" },
    { id = "user_for_db_2", name = "user_3", old_name = "user_2" }
  ]
  databases = [
    {
      id         = "database_1",
      name       = "db_1",
      owner_id   = "user_for_db_1",
      schemas    = ["test"],
      extensions = [{ name = "citext", schema = "public" }]
    },
    {
      id       = "database_2",
      name     = "db_2",
      owner_id = "user_for_db_2",
    }
  ]
  scripts = [
    {
      id                       = "test_shell_script",
      script                   = "${path.module}/bootstrap/test.sh",
      database_id              = "database_1",
      shell_script             = true,
      rerun_on_user_change     = true,
      rerun_on_variable_change = true,
      variables                = { "VAR_1" = "hello sh", "VAR_2" = "world!" },
      secrets = {
        "USERNAME_2" = { path = "${local.environment}/database-server/${local.server_name}/user/user_for_db_2", key = "username" }
      }
    },
    {
      id          = "test_sql_script",
      script      = "${path.module}/bootstrap/test.sql",
      database_id = "database_2",
      user_id     = "user_for_db_2",
      variables   = { "some_name1" = "hello sql", "some_name2" = "world!" },
      secrets = {
        "username_1" = { path = "${local.environment}/database-server/${local.server_name}/user/user_for_db_1", key = "username" }
      }
    },
    {
      id           = "test_create_function_foo",
      script       = "${path.module}/bootstrap/create_function.sh",
      shell_script = true
      database_id  = "database_1",
      variables    = { "RETURN_VALUE" = "foo", "FUNCTION_NAME" = "get_foo" },
    },
    {
      id           = "test_create_function_bar",
      script       = "${path.module}/bootstrap/create_function.sh",
      shell_script = true
      database_id  = "database_1",
      variables    = { "RETURN_VALUE" = "bar", "FUNCTION_NAME" = "get_bar" },
    },
  ]

  depends_on = [null_resource.postgres_docker, module.database_credentials]
}
