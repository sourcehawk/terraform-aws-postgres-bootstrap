# Terraform AWS Postgres User Module

This Terraform module creates a user in a Postgres database and stores the user's credentials in AWS Secrets Manager. If the credentials for the user are updated, the module updates the database user's credentials automatically.

Note that if the user is marked for destruction in the Terraform plan, it will not delete the user from the database. This limitation arises from using the null_resource and the destroy mechanism.

> Destroy-time provisioners and their connection configurations may only reference attributes of the related resource, via 'self', 'count.index', or 'each.key'.

## Usage

```hcl
module "postgres_user" {
  source = "terraform-aws-postgres-bootstrap/modules/postgres_init/user"

  conn = {
    server_name          = "my-database-server"
    host                 = "my-database-host"
    port                 = 5432
    engine               = "postgres"
    maintenance_database = "my_database"
    maintenance_user     = "my_database_superuser"
  }
  id = "my_user"
  name = "my_database_user"
}
```

## Inputs

| Name                | Description                                                                                                                                                                                                                    |  Type  | Default | Required |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :----: | :-----: | :------: |
| conn                | The connection to the database server                                                                                                                                                                                          | object |   n/a   |   yes    |
| id                  | A unique identifier for the user. Enables the renaming of user by updating the `name` variable and providing the `old_name`                                                                                                    | string |   n/a   |   yes    |
| name                | The user to create in the postgres instance. Credentials for the user are stored in a secret in AWS Secrets Manager. If this user has been created by a different resource, the creation will fail before any code is executed | string |   n/a   |   yes    |
| password            | The password for the user. Leave empty to generate a random password. The generated password will not be stored in the state file.                                                                                             | string |  null   |    no    |
| regenerate_password | When set to true, the password will be regenerated. Cannot be set to true when a password is being supplied.                                                                                                                   |  bool  |  false  |    no    |
| old_name            | When set, the username will be updated from `old_name` to the value of the `name` variable.                                                                                                                                    | string |  null   |    ni    |

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

| Name                         | Description                                   |
| ---------------------------- | --------------------------------------------- |
| user_credentials_secret_name | Name of the secret with the users credentials |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 5    |

## Requirements

| Name            | Version |
| --------------- | ------- |
| awscli          | >= 2    |
| postgres-client | >= 12   |

Additionally, a connection must be possible between your database server and the machine executing this module.

- For CI, run your CI runner from within the network where the database is running and make sure the CIDR block of the runner's subnet is whitelisted.
- For local execution against an RDS instance in AWS, create a [client VPN endpoint](https://docs.aws.amazon.com/vpc/latest/userguide/vpn-connections.html) to route traffic to your VPC when the VPN is activated.
