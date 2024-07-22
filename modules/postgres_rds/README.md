# Terraform AWS RDS Postgres Module

This module provisions an AWS RDS instance with the necessary security groups and IAM roles. It also creates a secrets manager secret to store the database credentials.

## Usage

```hcl
module "db" {
  source = "terraform-aws-postgres-bootstrap/modules/postgres_rds"

  environment             = "dev"
  identifier               = "unique-identifier"
  server_name             = "my-database-server"
  vpc_id                   = "vpc-0abcd1234efgh5678"
  db_subnet_ids            = ["subnet-0abcd1234efgh5678", "subnet-0abcd1234efgh5679"]
  postgres_version         = "15.5"
  instance_class           = "db.t3.medium"
  maintenance_database     = "postgres"
  maintenance_username     = "postgres"
  allocated_storage        = 100
  max_allocated_storage    = 200
  deletion_protection      = true
  skip_final_snapshot      = false
  allowed_cidrs            = [{ cidr_blocks = ["10.150.0.0/24"], description = "subnet xyz" }]
  parameter_group          = [
    {
      name         = "shared_preload_libraries"
      value        = "pg_stat_statements,pglogical,pg_cron"
      apply_method = "pending-reboot"
    }
  ]
}
```

## Inputs

Note: When an input is received as null and the field is not nullable, the default value of that input will be used.

Here is the updated markdown list according to the provided variable definitions:

| Name                       | Description                                                                                                                  | Type                                                                                              | Default      | Nullable |       Required        |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------ | :------: | :-------------------: |
| environment                | The name of environment to create the RDS instance in. Used for grouping credentials in AWS Secrets Manager.                 | `string`                                                                                          | n/a          |    No    |          Yes          |
| identifier                 | Unique identifier for the RDS instance                                                                                       | `string`                                                                                          | n/a          |    No    |          Yes          |
| server_name                | The name for the database server. Unique per environment. Used for grouping credentials in AWS Secrets Manager.              | `string`                                                                                          | n/a          |    No    |          Yes          |
| snapshot_identifier        | The identifier of the DB snapshot to restore from                                                                            | `string`                                                                                          | `null`       |   Yes    |          No           |
| existing_user_credentials  | Existing user credential for the RDS instance default user. (When importing an existing RDS instance)                        | `object({ username = string, password = string })`                                                | `null`       |   Yes    |          No           |
| vpc_id                     | The VPC id used to infer the DB subnet from                                                                                  | `string`                                                                                          | n/a          |    No    |          Yes          |
| db_subnet_ids              | The subnet ids to use for the DB. Subnet group will be created from these. If `subnet_group` is specified then ignored.      | `list(string)`                                                                                    | n/a          |    No    | Unless `subnet_group` |
| subnet_group               | The name of the DB subnet group to associate with the RDS instance. Will be created from `db_subnet_ids` if not specified    | `string`                                                                                          | n/a          |   Yes    |          No           |
| parameter_group            | A parameter group to attach to the RDS instance                                                                              | `object({ parameters = list(object({ name = string, value = string, apply_method = string })) })` | `null`       |   Yes    |          No           |
| allowed_subnet_ids         | The ids of subnets of which the CIDR block shall be able to access the db by default                                         | `list(string)`                                                                                    | n/a          |    No    |          Yes          |
| postgres_version           | The version of postgres (f.x 16)                                                                                             | `string`                                                                                          | n/a          |    No    |          Yes          |
| auto_minor_version_upgrade | Whether to allow minor version upgrades automatically                                                                        | `bool`                                                                                            | true         |    No    |          Yes          |
| instance_class             | The instance class of the RDS instance (f.x db.t2.micro)                                                                     | `string`                                                                                          | n/a          |    No    |          Yes          |
| maintenance_database       | The name of the database to create when the DB instance is created. If not specified, a database named 'postgres' is created | `string`                                                                                          | `null`       |   Yes    |          No           |
| maintenance_username       | The username of the postgres 'superuser'                                                                                     | `string`                                                                                          | `"postgres"` |    No    |          No           |
| allocated_storage          | The amount of storage to allocate to the RDS instance in GB                                                                  | `number`                                                                                          | `50`         |    No    |          No           |
| max_allocated_storage      | The maximum amount of storage to allocate to the RDS instance in GB                                                          | `number`                                                                                          | `null`       |   Yes    |          No           |
| deletion_protection        | Must be set to false before deleting the RDS instance.                                                                       | `bool`                                                                                            | `true`       |    No    |          No           |
| storage_encrypted          | Whether store is to be encrypted or not                                                                                      | `bool`                                                                                            | `true`       |    No    |          No           |
| storage_type               | The storage type to use for the RDS instance. Default is gp3.                                                                | `string`                                                                                          | `"gp3"`      |    No    |          No           |
| skip_final_snapshot        | Whether to skip the final snapshot when deleting the RDS instance                                                            | `bool`                                                                                            | `false`      |    No    |          No           |
| allowed_cidrs              | A list of additional CIDRs to allow access to the RDS instance                                                               | `list(object({ cidr_blocks = list(string), description = string }))`                              | `[]`         |    No    |          No           |
| regenerate_password        | When set to true, the password of the master user will be regenerated                                                        | bool                                                                                              | `false`      |    No    |

## Outputs

| Name                              | Description                                                                                                                                                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| rds_instance                      | The [aws_db_instance object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) created.                                                                                     |
| database_access_security_group_id | The ID of a security group that allows network traffic between the database and another AWS resource when attached to the resource. Note that this is only needed if the resource is not within the allowed CIDRs. |
| database_security_group_id        | The ID of the security group attached to the RDS instance.                                                                                                                                                         |
| database_credentials_secret_name  | The name of the secret containing the database credentials.                                                                                                                                                        |
| user_credentials_secret_name      | The name of the secret containing the user credentials.                                                                                                                                                            |

## Importing Existing Databases

There are two options when it comes to importing existing databases into this terraform code's state.

### Approach 1: Using Snapshot Identifier

Utilize the `snapshot_identifier` variable to specify a snapshot of another RDS instance for creating a new RDS instance.

```hcl
module "db" {
  source = "path/to/module"

  identifier               = "db-identifier"
  snapshot_identifier      = "snapshot-identifier"
  existing_user_credentials = {
    username = "postgres"
    password = "supersecret"
  }
  # remaining configuration
}
```

### Approach 2: Manual Import

Manually import the existing RDS instance into Terraform state using the `terraform import` command. Any changes to it detected according to the configuration will be applied with the next terraform apply command.

> terraform import -var-file=`<target>`.tfvars module.postgres_rds_instance[`<index>`].aws_db_instance.this `<rds-identifier>`

```hcl
module "db" {
  source = "path/to/module"

  identifier               = "<rds-identifier>"
  subnet_group             = "old-subnet-group"
  existing_user_credentials = {
    username = "postgres"
    password = "supersecret"
  }
  # remaining configuration
}
```

For both options, we declared the `existing_user_credentials` variable, specifying the RDS master user's `username` and `password`. After applying Terraform code with `existing_user_credentials`, you can remove it and reapply the Terraform code to manage the password using the terraform module and eliminate it from the terraform state. Note that this **will not change the password**.

### With pre-populating AWS secret

To prevent the password from being exposed by Terraform, you can also pre-create a secret in AWS Secrets Manager on the format specified in the [user credentials module](../credentials/user/) before applying and leave out the `existing_user_credentials` configuration. Make sure that the `<id>` part of the secret name is set to `master`.

### Importing from other subnet

If your imported database is in a subnet group in the same VPC as the default subnet group used by the module, you can specify `subnet_group` to use the existing one. If your database is not in the correct VPC, first transfer your RDS instance into a subnet group in the correct VPC. Once your database is in the correct VPC, and after importing, you can reapply without specifying `subnet_group` to allow the module to handle the subnet group creation according to the specified `db_subnet_ids`.

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
