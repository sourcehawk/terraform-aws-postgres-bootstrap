terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/docker-init-script"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment          = "test"
  server_name          = "docker-init-script"
  maintenance_database = "postgres"
  maintenance_user     = "postgres"
  engine               = "postgres"
  maintenance_password = "hCRj8PHUYbqVJ%DL28$NW$a8"
  database_port        = 10565
  database_host        = "localhost"
}

# Create master user credentials
module "user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  name                    = local.maintenance_user
  password                = local.maintenance_password
  master_user             = true
  recovery_window_in_days = 0
}

# Create master database credentials - required for scripts to get connection details for the database they are running against
module "database_credentials" {
  source = "../../modules/credentials/database"

  server_name     = local.server_name
  environment     = local.environment
  database        = local.maintenance_database
  host            = local.database_host
  port            = local.database_port
  engine          = local.engine
  user_id         = module.user_credentials.id # "master"
  user_role       = "owner"
  master_database = true

  # We must depend on the user_credentials module because the user credentials are fetched from Secrets Manager
  depends_on = [module.user_credentials]
}

resource "null_resource" "postgres_docker" {
  provisioner "local-exec" {
    environment = {
      "PG_USER"     = local.maintenance_user
      "PG_DATABASE" = local.maintenance_database
      "PG_PORT"     = local.database_port
      # If you declare it here, it will be stored in the state file, you can move it inside the template to prevent that.
      "PG_PASSWORD" = local.maintenance_password
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

module "postgres_init_script" {
  source = "../../modules/postgres_init/modules/script"

  id           = "test_shell_script"
  script       = "${path.module}/test.sh"
  shell_script = true
  variables = {
    "VAR_1" = "value_1"
  }
  secrets = {
    "SECRET_1" = {
      path = "${local.environment}/database-server/${local.server_name}/user/user_for_db_2",
      key  = "password"
    }
  }
  rerun_on_user_change     = true
  rerun_on_variable_change = true

  conn = {
    host                 = local.database_host
    port                 = local.database_port
    engine               = local.engine
    maintenance_user     = local.maintenance_user
    maintenance_database = local.maintenance_database
    environment          = local.environment
    server_name          = local.server_name
  }

  depends_on = [null_resource.postgres_docker, module.database_credentials]
}
