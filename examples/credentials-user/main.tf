terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/credentials-user"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment          = "test"
  server_name          = "credentials-user"
  maintenance_database = "postgres"
  maintenance_user     = "postgres"
  maintenance_password = "hCRj8PHUYbqVJ%DL28$NW$a8"
  other_user           = "user_1"
}

# Create a master user's credentials. (supplying the password - not recommended)
module "user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  name                    = local.maintenance_user
  password                = local.maintenance_password
  master_user             = true
  recovery_window_in_days = 0
}

# Create another user credentials without supplying a password
module "other_user_credentials" {
  source = "../../modules/credentials/user"

  server_name             = local.server_name
  environment             = local.environment
  id                      = "user_for_db_x" # must be specified when master_user = false
  name                    = local.other_user
  master_user             = false
  recovery_window_in_days = 0
}
