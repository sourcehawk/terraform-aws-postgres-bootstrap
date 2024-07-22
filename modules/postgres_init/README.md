# Terraform AWS Postgres Init Module

This Terraform module initializes a Postgres database server by creating users, databases, and running scripts. It uses three submodules: [user](./modules/user), [database](./modules/database), and [script](./modules/script).

Execution order:

- users
- databases
- scripts

Individually, the arrays of `users`/`databases`/`scripts` are executed in arbitrary order as Terraform does not support in-order execution of arrays or maps of resources. This means you cannot rely on your `scripts` array to execute in the order you pass them in and should treat them as non-dependent entities being applied to your database. You can, however, rely on the fact that the users are created before the databases, and the databases are created before any scripts are executed.

## Usage

```hcl
module "postgres_init" {
  source = "github.com/yourorg/postgres-init/aws"

  conn = {
    server_name          = "my-database-server"
    environment          = "dev"
    host                 = "my-database-host"
    port                 = 5432
    engine               = "postgres"
    maintenance_database = "my-database"
    maintenance_user     = "my-database-superuser"
  }
  users = [
    {
      id   = "my_user"
      name = "user_1"
    }
  ]
  databases = [
    {
      id         = "my_database"
      name       = "database_1"
      owner_id   = "my_user"
      schemas    = ["my-schema1", "my-schema2"]
      extensions = [
        {
          name   = "my-extension"
          schema = "my-schema"
        }
      ]
    }
  ]
  scripts = [
    {
      script       = "../path/to/my-script.sql"
      shell_script = false
      user_id      = "my_user"
      database_id  = "my_database"
      variables    = { "var1" = "value1", "var2" = "value2" }
      secrets      = {
        "var3" = { path = "/path/to/myawssecret", key = "password" },
        "var4" = { path = "/path/to/secret" }
      }
    }
  ]
}
```

## Inputs

| Name      | Description                                                                                                                                                                |     Type     | Default | Required |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------: | :-----: | :------: |
| conn      | The connection to the database server                                                                                                                                      |    object    |   n/a   |   yes    |
| users     | A list of users to create. Execution order is **not** guaranteed and should be treated as random. See the [User](./modules/user/) module for for attribute details         | list(object) |  `[]`   |    no    |
| databases | A list of databases to create. Execution order is **not** guaranteed and should be treated as random. See the [Database](./modules/database/) module for attribute details | list(object) |  `[]`   |    no    |
| scripts   | A list of scripts to run. Execution order is **not** guaranteed and should be treated as random. See the [Script](./modules/script/) module for for attribute details      | list(object) |  `[]`   |    no    |

### `conn` Variable Attributes

The `conn` variable is an object that contains the connection details for the database server. Here are the attributes of the `conn` variable:

| Attribute            | Description                                                                         |
| -------------------- | ----------------------------------------------------------------------------------- |
| server_name          | The name for the database server                                                    |
| environment          | The environment that the database server belongs to                                 |
| host                 | The host of the database server                                                     |
| port                 | The port of the database server                                                     |
| engine               | The engine of the database server (e.g., "postgres")                                |
| maintenance_database | The default database on the server                                                  |
| maintenance_user     | The username of the default user for the database server                            |
| password             | Password for existing database. Leave undefined / null if to be fetched from secret |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 5    |

## Requirements

| Name            | Version |
| --------------- | ------- |
| awscli          | >= 2    |
| postgres-client | >= 12   |
| openssl         | >= 3    |
| linux/mac       |         |

Additionally, a connection must be possible between your database server and the machine executing this module.

- For CI, run your CI runner from within the network where the database is running and make sure the CIDR block of the runner's subnet is whitelisted.
- For local execution against an RDS instance in AWS, create a [client VPN endpoint](https://docs.aws.amazon.com/vpc/latest/userguide/vpn-connections.html) to route traffic to your VPC when the VPN is activated.

## Submodules

- [User](./modules/user)
- [Database](./modules/database)
- [Script](./modules/script)
