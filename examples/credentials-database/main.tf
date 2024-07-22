terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/credentials-database"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment          = "test"
  server_name          = "credentials-database"
  maintenance_database = "postgres"
  maintenance_user     = "postgres"
}

# Create a master user's credentials - must be done before the database credentials can be created
# because the database credentials retrieve the user's credentials from the secret manager
module "user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  id                      = "master" # must be master or null when master_user = true
  name                    = local.maintenance_user
  master_user             = true
  recovery_window_in_days = 0
}

# Create the master database credentials
module "database_credentials" {
  source = "../../modules/credentials/database"

  server_name     = local.server_name
  environment     = local.environment
  id              = "master" # must be master or null when master_database = true
  database        = local.maintenance_database
  host            = "localhost"
  port            = 5432
  engine          = "postgres"
  user_id         = "master"
  user_role       = "owner"
  master_database = true
}
