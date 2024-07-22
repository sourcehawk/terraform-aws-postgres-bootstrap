# Example for database credentials submodule

Example for [database credentials submodule](../../modules/credentials/database/)

Requirements

- awscli
- terraform
- openssl
- linux/mac

## Running test

Create `.tfbackend` file

```hcl
region = "eu-west-1"
bucket = "my-bucket-name"
key    = "terraform-aws-postgres-bootstrap/credentials-database.tfstate"

```

- log in with awscli
- terraform init -backend-config=".tfbackend"
- terraform plan -out=tfplan
- terraform apply tfplan

## Cleaning up after test

- terraform destroy
