# Terraform AWS Secrets Manager User Credentials Module

This Terraform module creates user credentials and stores them in AWS Secrets Manager.

- Path in AWS: `<environment>/database-server/<server_name>/user/<id>`
- Available secret keys:
  - `username`: The user's username
  - `password`: The user's password
  - `id`: The creation ID of the user (`master` when server default user)

## Usage

```hcl
module "user_credentials" {
  source = "path/to/module"

  server_name             = "my-server"
  environment             = "test"
  id                      = "my_user"
  name                    = "user"
  recovery_window_in_days = 0
  master_user             = false
}
```

You can supply the password if you want to upload existing credentials to AWS Secrets Manager using the format other modules use. You can later remove it to let the module generate a new password for you.

Note that the Terraform state will not contain the password as this secret is generated with a null resource using `awscli`.

## Inputs

| Name                    | Description                                                                                                                                                                                                     |  Type  | Default | Required |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----: | :-----: | :------: |
| id                      | The ID of the user to create credentials for. Used in the secret name.                                                                                                                                          | string |   n/a   |   yes    |
| server_name             | The name of the database server to create credentials for. This is used to group the credentials in AWS Secrets Manager.                                                                                        | string |   n/a   |   yes    |
| environment             | The environment to create the credentials in. This is used to group the credentials in AWS Secrets Manager.                                                                                                     | string |   n/a   |   yes    |
| name                    | The database username to create credentials for. The credentials are stored in a secret in AWS Secrets Manager.                                                                                                 | string |   n/a   |   yes    |
| password                | The password for the user. Leave empty to generate a random password.                                                                                                                                           | string | `null`  |    no    |
| recovery_window_in_days | The number of days that Secrets Manager waits before it can delete the secret.                                                                                                                                  | number |   `0`   |    no    |
| master_user             | Whether the user is the master user of the database server. When set to true, the `id` will be set to 'master'.                                                                                                 |  bool  |   n/a   |   yes    |
| description             | A description of the created secret.                                                                                                                                                                            | string | `null`  |    no    |
| regenerate_password     | When set to true, the password will be regenerated. Note that when you turn the flag to false, Terraform reports that the resource needs to be updated, but the null resource will not generate a new password. |  bool  |  false  |    no    |

## Outputs

| Name        | Description                                    |
| ----------- | ---------------------------------------------- |
| secret_name | Name of the secret with the user's credentials |
| id          | Creation id of the user                        |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | ~> 5    |

## Requirements

| Name      | Version |
| --------- | ------- |
| awscli    | >= 2    |
| openssl   | >= 3    |
| linux/mac |         |

The credentials are generated using a null resource; therefore, the system executing the Terraform apply command must meet these requirements.
