# Terraform AWS Postgres Database Module

This Terraform module creates a Postgres database, schemas, and extensions on an existing database server. It retrieves the superuser credentials from AWS Secrets Manager and creates a new set of connection credentials for the database owner. This means that the superuser credentials must exist in Secrets Manager beforehand. They are automatically created as part of the root module, but if you need to create them manually, you can use the [credentials/user](../../../credentials/user/) module to deploy the database server's superuser credentials to AWS secrets manager.

If the credentials for the database are updated, the module will automatically update the database credentials.

This module uses local-exec commands, so the execution environment (whether CI/CD or local) must meet the [requirements](#requirements).

Note that none of the created resources in the database can be destroyed by Terraform once they are created. Even though Terraform reports them as "destroyed," they will not be removed from the database.

## Usage

```hcl
module "postgres_database" {
  source = "terraform-aws-postgres-bootstrap/modules/postgres_init/database"

  conn = {
    server_name          = "my-database-server"
    environment          = "test"
    host                 = "my-database-host"
    port                 = 5432
    engine               = "postgres"
    maintenance_database = "my_database"
    maintenance_user     = "my_database_superuser"
  }

  id        = "my-db"
  name      = "db"
  owner_id  = "my_database_user"
  schemas   = ["my-schema1", "my-schema2"]
  extensions = [
    {
      name   = "my-extension"
      schema = "my-schema1"
    }
  ]
}
```

## Inputs

| Name                  | Description                                                                                                                                                     |                   Type                   | Default | Required |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------: | :-----: | :------: |
| conn                  | The connection to the database server                                                                                                                           |                  object                  |   n/a   |   yes    |
| id                    | A unique identifier for the database resource. It is used to identify whether the database was renamed or not so that the correct SQL can be executed.          |                  string                  |   n/a   |   yes    |
| name                  | The name of the database to create                                                                                                                              |                  string                  |   n/a   |   yes    |
| owner_id              | The id of the user that shall own the database. This is the `id` of some user created by the [user module](../user/)                                            |                  string                  |   n/a   |   yes    |
| owner_credentials_sha | The sha256 hash of the user credentials secret string. This allows for properly triggering recreation of database credentials when the user credentials change. |                  string                  |   n/a   |   yes    |
| schemas               | The schemas to create in the database                                                                                                                           |               list(string)               |  `[]`   |    no    |
| extensions            | The extensions to create in the database                                                                                                                        | list(object{name=string, schema=string}) |  `[]`   |    no    |
| old_name              | Previous name of database, required when renaming                                                                                                               |                  string                  |   n/a   |    no    |

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

## Outputs

| Name        | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| secret_name | Name of the secret with the database connection credentials |
| id          | The id of the database                                      |

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
