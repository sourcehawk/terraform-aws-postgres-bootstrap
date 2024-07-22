terraform {
  backend "s3" {}
  required_providers {
    aws = "~> 5"
  }
}

provider "aws" {
  default_tags {
    tags = {
      "terraform-module" = "terraform-aws-postgres-bootstrap/examples/rds-init"
      "managed-by"       = "terraform"
    }
  }
}

locals {
  environment = "test"
  server_name = "rds-init"
}

module "rds_init" {
  source = "../../"

  environment = local.environment
  database_configs = [
    {
      rds = {
        identifier                 = "terraform-aws-postgres-bootstrap"
        server_name                = local.server_name
        vpc_id                     = var.vpc_id
        db_subnet_ids              = var.db_subnet_ids
        postgres_version           = "16.3"
        auto_minor_version_upgrade = false # false because we specify minor version
        instance_class             = "db.t3.small"
        allocated_storage          = 20 # Gb - this is aws minimum
        storage_type               = "gp3"
        storage_encrypted          = true
        maintenance_username       = "postgres"
        maintenance_database       = "postgres"
        subnet_group               = null # null because using db_subnet_ids
        max_allocated_storage      = 25   # Gb - must increase at least 10%
        deletion_protection        = false
        skip_final_snapshot        = true
        existing_user_credentials  = null # use when importing existing db
        regenerate_password        = true
        allowed_cidrs              = var.allowed_cidrs
        parameter_group = [
          {
            name         = "shared_preload_libraries"
            value        = "pg_stat_statements,pglogical,pg_cron"
            apply_method = "pending-reboot"
          }
        ]
      }
      init = {
        users = [
          { id = "user_for_db_1", name = "user_1", password = "foobarbaz" },
          { id = "user_for_db_2", name = "user_2" }
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
            script                   = "${path.module}/test.sh",
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
            script      = "${path.module}/test.sql",
            database_id = "database_2",
            user_id     = "user_for_db_2",
            variables   = { "some_name1" = "hello sql", "some_name2" = "world!" },
            secrets = {
              "username_1" = { path = "${local.environment}/database-server/${local.server_name}/user/user_for_db_1", key = "username" }
            }
          }
        ]
      }
    }
  ]
}
