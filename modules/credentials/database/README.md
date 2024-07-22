# Terraform AWS Secrets Manager Database Credentials Module

This Terraform module creates database connection credentials and stores them in AWS Secrets Manager. To use this module, you must first create the user credentials with the [user module](../user/).

- Path in AWS: `<environment>/database-server/<server_name>/database/<id>/credentials`
- Available secret keys:
  - `host`: The database server host
  - `port`: The database port
  - `database`: The database name
  - `usernane`: The database owner username
  - `password`: The database owner password
  - `engine`: The engine (postgres)
  - `id`: The database id given in terraform

## Usage

```hcl
module "database_credentials" {
  source = "path/to/module"

  server_name       = "my-database-server"
  host              = "my-database-host"
  port              = 5432
  database          = "my-database"
  user_id           = "my_database_user"
  user_role         = "owner"
  engine            = "postgres"
}
```

Note that the Terraform state will not contain the password as this secret is generated with a null resource using `awscli`.

## Terraform plan destroy notice

Because the Terraform plan is unable to evaluate the contents of a secret datasource until after it is applied, the database credentials created
by this module will always be marked for recreation, however this is a false positive, as the credentials will not change.

This problem is unfortunately uncirumventable.

## Inputs

| Name        | Description                                                                                      |  Type  |  Default   | Required |
| ----------- | ------------------------------------------------------------------------------------------------ | :----: | :--------: | :------: |
| id          | The id of the database to create credentials for. Used in secret name                            | string |    n/a     |   yes    |
| server_name | The identifier for the database server                                                           | string |    n/a     |   yes    |
| host        | The host of the database server                                                                  | string |    n/a     |   yes    |
| port        | The port of the database server                                                                  | number |    n/a     |   yes    |
| database    | The name of the database                                                                         | string |    n/a     |   yes    |
| user_id     | The id of the existing database user to use for the connection credentials                       | string |    n/a     |   yes    |
| user_role   | A description of the role of the user in the given database (f.x owner / user). Used for tagging | string |    n/a     |   yes    |
| engine      | The engine of the database server                                                                | string | `postgres` |   yes    |

## Outputs

| Name        | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| secret_name | Name of the secret with the database connection credentials |
| id          | Creation id of the database                                 |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 5    |

## Requirements

- The user of the database must have been bootstrapped with the [user credentials module](../user/). The password for the secret created is extracted from the user secret.
