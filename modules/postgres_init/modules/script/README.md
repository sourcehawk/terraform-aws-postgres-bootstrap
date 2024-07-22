# Terraform AWS Postgres Script Module

This Terraform module executes a script (either shell or SQL) in a Postgres database. The script is executed with a user whose credentials are stored in AWS Secrets Manager.

Note that none of the created database resources can be destroyed by terraform once they are created. So even though terraform reports them as being "destroyed" they will not be removed from the database.

## Usage

```hcl
module "postgres_script" {
   source = "terraform-aws-postgres-bootstrap/modules/postgres_init/script"

  conn = {
    server_name          = "my-database-server"
    environment          = "test"
    host                 = "my-database-host"
    port                 = 5432
    engine               = "postgres"
    maintenance_database = "my-database"
    maintenance_user     = "my-database-superuser"
  }
  id           " "myscript"
  script       = "my-script.sh"
  shell_script = true
  variables    = {
    "VAR1" = "value1"
    "VAR2" = "value2"
  }
  database_id = "my_database"
  user_id     = "my_database_user"
}
```

### What to script?

While many examples might show simple SQL statements like `INSERT` or `CREATE TABLE`, those are typically better handled with other migration tools. Scripting in this module should be used for bootstrapping functionality that requires Infrastructure as Code (IaC). This can be for examples this such as:

1. **Setting User Roles**: Assign roles and permissions to users
2. **Creating Foreign Data Wrappers (FDWs)**: Set up FDWs and server definition for cross-database queries.
3. **Dynamic SQL/Function Creation**: Generate dynamic functions or other dynamic SQL based on variables and secrets.

### Script repeatability

Scripts must be repeatable because changes to an SQL script that has already been applied with Terraform will trigger the module to re-execute the script. Non-repeatable scripts will cause your apply process to fail on subsequent executions.

For bash scripts, use IF NOT EXISTS queries to handle repeatability:

```sql
IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='myrole') THEN
  CREATE ROLE myrole;
END IF;
```

### Commiting transaction

To mitigate issues with parallel script execution (Terraform executes everything possible in parallel), wrap your SQL scripts in transaction blocks:

```sql
BEGIN;
-- sql code
COMMIT;
```

### Creating shell scripts

When `shell_script = true`, the script must start the psql session. Environment variables required to start a session are available by default, meaning that you do not need to specify credentials when starting a psql session:

```bash
psql -v ON_ERROR_STOP=1 <<EOSQL
BEGIN;
SELECT ...
COMMIT;
EOSQL
```

- By default, the maintenance database is used if you do not specify your own database in the module configuration using the `database_id` variable.
- The maintenance user (superuser) is used unless a different user is specified in the `user_id` variable.

To escape the DO block dollar signs in shell scripts:

```bash
psql -v ON_ERROR_STOP=1 <<EOSQL
BEGIN;
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_foreign_data_wrapper WHERE fdwname = '${FDW_NAME}') THEN
      CREATE EXTENSION IF NOT EXISTS ${FDW_NAME};
   END IF;
END\$\$;
COMMIT;
EOSQL
```

### Using variables and secrets in shell script

All variables and secrets defined in the script configuration section are made available to executed files as environment variables. Secrets are fetched from AWS Secrets Manager.

```hcl
id = "myscript"
script = "path/to/script.sh"
shell_script = true
variables = {
  "SOME_NAME" = "Foobar"
},
secrets = {
  "SOME_OTHER_NAME" = { path = "/aws/secret/path", key = "secretkey" }
}
```

Example usage in a script:

```bash
psql -v ON_ERROR_STOP=1 <<EOSQL
BEGIN;
INSERT INTO foobar (name) VALUES ('$SOME_NAME');
CREATE SCHEMA IF NOT EXISTS $SOME_OTHER_NAME;
COMMIT;
EOSQL
```

### Using variable and secrets in sql script

Variables are passed to SQL scripts using the `-v` option with `psql`.

Example configuration:

```hcl
id = "myscript"
script = "path/to/script.sh"
shell_script = true
rerun_on_variable_change = true
variables = {
  "SOME_NAME" = "foobar"
},
secrets = {
  "SOME_OTHER_NAME" = { path = "/aws/secret/path", key = "secretkey" }
}
```

Example usage in a SQL script:

```sql
BEGIN;
INSERT INTO foobar (name) VALUES (:'SOME_NAME');
INSERT INTO foobar (name) VALUES (:'SOME_OTHER_NAME');
COMMIT;
```

For unquoted values:

```sql
BEGIN;
CREATE SCHEMA IF NOT EXISTS :SOME_NAME;
CREATE SCHEMA IF NOT EXISTS :SOME_OTHER_NAME;
COMMIT;
```

**Note**: variables cannot be used within `DO` blocks in SQL scripts.

## Inputs

| Name                     | Description                                                                                                                                                            | Type                                           | Default  | Required |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | -------- | -------- |
| conn                     | The connection to the database server                                                                                                                                  | object                                         | n/a      | yes      |
| id                       | The id of the script. Used to uniquely identify the script so that each script can run multiple times on the same database.                                            | string                                         | n/a      | yes      |
| script                   | The path to the script to execute. Relative to the execution directory                                                                                                 | string                                         | n/a      | yes      |
| shell_script             | Whether the script is a shell script or not. If not, it is assumed to be a SQL script                                                                                  | bool                                           | `false`  | no       |
| variables                | Variables to set when executing the script. For shell scripts, these will be set in the shell. For SQL scripts, these will be passed as arguments using the `-v` flag  | map(string)                                    | `{}`     | no       |
| secrets                  | Variables to fetch from AWS Secrets Manager. For shell scripts, these will be set in the shell. For SQL scripts, these will be passed as arguments using the `-v` flag | map(object{path=string, key=optional(string)}) | `{}`     | no       |
| database_id              | The database to execute the script in. If not provided, the script will be executed in the `maintenance_database` database                                             | string                                         | `master` | no       |
| user_id                  | The id of the user to execute the script with. If not provided, the script will be executed as the `maintenance_user` user                                             | string                                         | `master` | no       |
| rerun_on_variable_change | Whether to rerun the script when the variables or secrets change. If set to false, the script will not be updated when it changes.                                     | bool                                           | `false`  | no       |
| rerun_on_user_change     | Whether to rerun the script when the script execution user changes in any way. If set to false, the script will not be updated when the user changes.                  | bool                                           | `false`  | no       |

### `conn` Variable Attributes

The `conn` variable is an object containing the connection details for the database server. Attributes include:

| Attribute            | Description                                                                        |
| -------------------- | ---------------------------------------------------------------------------------- |
| server_name          | The name for the database server                                                   |
| environment          | The environment that the database server belongs to                                |
| host                 | The host of the database server                                                    |
| port                 | The port of the database server                                                    |
| engine               | The engine of the database server (e.g., "postgres")                               |
| maintenance_database | The default database on the server                                                 |
| maintenance_user     | The username of the default user for the database server                           |
| password             | Password for the existing database. Leave undefined if to be fetched from a secret |

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
