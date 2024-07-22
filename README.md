# Terraform AWS Postgres Bootstrap

This module is designed to simplify and automate the provisioning of PostgreSQL databases on Amazon Web Services (AWS) with IaC capabilities. As is most often the case, you will have applications and systems deploying managing their own migrations. Those applications and systems however do not always address the initial configuration that needs to be done before those migrations can run, or before the software can use the database. This is where this module comes in handy.

Note that if you only want to bootstrap your database, and do not need an RDS instance, you can use the [postgres_init submodule](modules/postgres_init/).

## Key Features

- Automated PostgreSQL Setup: Provision a PostgreSQL instance on AWS with minimal configuration.
- Credential Management: Securely manage database and user credentials without credentials being stored in the state.
- Dynamic SQL generation: Dynamically generate SQL using variables and secrets
- Security Configurations: Automatically set up security groups and other necessary configurations to ensure secure access to the database.
- Modular Design: Utilize sub-modules for managing databases, users and custom scripts.

## Usage

### Minimal example

```hcl
module "postgres_databases" {
  source = "terraform-aws-postgres-bootstrap"

  environment = "dev"
  database_configs = [
    {
      rds = {
        identifier        = "my-db"
        server_name       = "my-database"
        vpc_id            = "vpc-xxxxxxxx"
        db_subnet_ids     = ["subnet-1234abcd", "subnet-5678efgh"]
        postgres_version  = "16"
        instance_class    = "db.t3.small"
        allocated_storage = 50
      }
      init = {
        users = [{ name = "myuser" }]
        databases = [{
          name    = "mydb",
          owner   = "myuser",
          schemas = ["myschema1"]
          extensions = [{
            name   = "myextension",
            schema = "myschema1"
          }]
        }]
        scripts = [{
          id        = "create_foo_config_table"
          script    = "../path/to/script.sql",
          database  = "mydb",
          variables = { "FOO" : "foo" },
          secrets = {
            "BAR" = { path = "/aws/secret/path", key = "mysecret" }
          }
          shell_script = true
        }]
      }
    }
  ]
}
```

### Full example

```hcl
module "terraform-aws-postgres-bootstrap" {
  source = "terraform-aws-postgres-bootstrap"

  environment = "dev"
  database_configs = [
    {
      rds = {
        identifier                 = "my-db"
        server_name                = "my-database-server"
        vpc_id                     = "vpc-xxxxxxxx"
        db_subnet_ids              = ["subnet-1234abcd", "subnet-5678efgh"]
        postgres_version           = "16.3"
        auto_minor_version_upgrade = false # false because we specify minor version
        instance_class             = "db.t3.small"
        allocated_storage          = 50 # Gb
        storage_type               = "gp3"
        storage_encrypted          = true
        maintenance_username       = "postgres"
        maintenance_database       = "postgres"
        subnet_group               = null # null because of db_subnet_ids
        max_allocated_storage      = 500  # Gb
        deletion_protection        = true
        skip_final_snapshot        = false
        existing_user_credentials  = null # use when importing existing db
        allowed_cidrs              = [
          { cidr_blocks = ["10.150.0.0/24"], description = "private-subnet-1"},
          { cidr_blocks = ["10.150.1.0/24"], description = "private-subnet-2"}
        ]
        parameter_group = [
          {
            name         = "shared_preload_libraries"
            value        = "pg_stat_statements,pglogical,pg_cron"
            apply_method = "pending-reboot"
          }
        ]
      }
      init = {
        users = [{ name = "user_1", password = "foobar" }, { name = "user_2", regenerate_password = true }]
        databases = [
          {
            name    = "db_1",
            owner   = "user_1",
            schemas = ["schema_1_db_1"]
            extensions = [
              {
                name   = "pg_search",
                schema = "schema_1_db_1"
              }
            ]
          },
          {
            name  = "db_2",
            owner = "user_2",
          }
        ]
        scripts = [
          {
            id        = "create_foo_config_table"
            script    = "../path/to/script.sql",
            database  = "db_1",
            variables = { "FOO" : "foo" },
            secrets = {
              "BAR" = { path = "/aws/secret/path", key = "mysecret" }
            }
            shell_script = false
          },
          {
            id        = "update_user_1_role"
            script    = "../path/to/script.sh",
            database  = "db_2",
            user      = "user_2",
            variables = { "OTHER_USER" : "user_1" },
            secrets = {
              "OTHER_USER_PASSWORD" = {
                path = "/dev/database-server/my-database-server/user/user_1",
                key = "password"
              }
            }
            shell_script             = true
            rerun_on_user_change     = true
            rerun_on_variable_change = true
        }]
      }
    }
  ]
}
```

This example creates the following:

1. An RDS instance with the given specifications.
2. Two users: `user_1` and `user_2`.
3. Two databases:
   - `db_1`:
     - Owned by `user_1`.
     - Contains the schema `schema_1_db_1`.
     - Has the extension `pg_search` in schema `schema_1_db_1`.
   - `db_2`:
     - Owned by `user_2`.
4. Executes the following scripts:
   - `../path/to/script.sql`:
     - An SQL script executed on database `db_1`.
     - Executed by the database server maintenance user (superuser).
     - Receives the variable `FOO`.
     - Receives the variable `BAR`, extracted from AWS Secrets Manager.
   - `../path/to/script.sh`:
     - A shell script executed on database `db_2`.
     - Executed by user `user_2`.
     - Receives the environment variable `OTHER_USER`.
     - Receives the environment variable `OTHER_USER_PASSWORD`, extracted from AWS Secrets Manager.
     - Configured to rerun when the script execution user's credentials change.
     - Configured to rerun when the variables and secrets passed to the script change.

### Good to know

#### Using additional user credentials in scripts

The module creates the credentials for your database users which you can use in your `scripts` for database initialization, (f.x creating fdw's or servers). You can retrieve them from AWS secrets manager. The credentials are always created before the scripts execute. See the [user credentials module](modules/credentials/user/) and the [database credentials moduel](modules/credentials/database/) for the format of the secret name.

Please review the [script submodule](modules/postgres_init/modules/script) for a detailed description on how to implement the bootstrapping scripts. There are also examples in the [examples directory](examples/)

## Inputs

| Name             | Description                                                                     | Type                                          | Default | Required |
| ---------------- | ------------------------------------------------------------------------------- | --------------------------------------------- | ------- | :------: |
| environment      | A unique identifier for the environment. Used for tagging and naming resources. | `string`                                      | n/a     |   yes    |
| database_configs | The configurations of the databases to create.                                  | `list(object({rds = object, init = object}))` | n/a     |   yes    |

## Database Configurations

The `database_configs` variable is a list of objects, each representing a database to be created along with bootstrapping configuration.

A database configuration object consists of two keys, namely `rds` and `init`.

- The `rds` key configures the input variables for the postgres_rds submodule which creates the desired RDS instance to specification. For details on the configuration options see the [postgres_rds submodule](modules/postgres_rds/)

- The `init` key configures the input variables for the postgres_init submodule, which bootstraps the RDS instance to the required specification. This includes adding users, creating databases, schemas, extensions, and executing arbitrary scripts using variables and secrets from AWS Secrets Manager. For details on the configuration options, see the [postgres_init submodule](modules/postgres_init/)

In the configuration, unspecified optional keys default to null. The submodules then use this null value to apply default values when the fields are specified as non-nullable.

## Outputs

| Name               | Description                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------- |
| postgres_instances | Map of postgres_rds module output with each key being the identifier of the RDS instance created.             |
| postgres_inits     | Map of postgres_init module output with each key being the identifier of the RDS instance it was executed on. |

## Requirements

| Name            | Version |
| --------------- | ------- |
| awscli          | >= 2    |
| postgres-client | >= 12   |
| openssl         | >= 3    |
| linux/mac       |         |
