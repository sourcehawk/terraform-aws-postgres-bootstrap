terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/docker-init-database"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment          = "test"
  server_name          = "docker-init-database"
  maintenance_database = "postgres"
  maintenance_user     = "postgres"
  maintenance_password = "hCRj8PHUYbqVJ%DL28$NW$a8"
  database_port        = 10565
  database_host        = "localhost"
}

# Create master user credentials - we don't need to create the database credentials because we're supplying the password with the `conn` variable,
# meaning the secret does not need to be fetched from Secrets Manager
module "user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  name                    = local.maintenance_user
  password                = local.maintenance_password
  master_user             = true
  recovery_window_in_days = 0
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

module "postgres_init_database" {
  source = "../../modules/postgres_init/modules/database"

  conn = {
    host                 = local.database_host
    port                 = local.database_port
    engine               = "postgres"
    maintenance_user     = local.maintenance_user
    password             = local.maintenance_password
    maintenance_database = local.maintenance_database
    environment          = local.environment
    server_name          = local.server_name
  }
  id       = "example_database"
  name     = "example_database"
  owner_id = module.user_credentials.id

  depends_on = [null_resource.postgres_docker, module.user_credentials]
}

# Rename the database (comment out the above module declaration and uncomment this one after initial apply)
# module "postgres_init_database" {
#   source = "../../modules/postgres_init/modules/database"

#   conn = {
#     host                 = local.database_host
#     port                 = local.database_port
#     engine               = "postgres"
#     maintenance_user     = local.maintenance_user
#     password             = local.maintenance_password
#     maintenance_database = local.maintenance_database
#     environment          = local.environment
#     server_name          = local.server_name
#   }
#   id       = "example_database"
#   name     = "new_example_database"
#   old_name = "example_database"
#   owner_id = module.user_credentials.id

#   depends_on = [null_resource.postgres_docker, module.user_credentials]
# }
