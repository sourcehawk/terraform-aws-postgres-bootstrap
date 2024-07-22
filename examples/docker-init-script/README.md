# Example for postgres init script submodule

Example for [postres_init script submodule](../../modules/postgres_init/modules/script/) using postgres in a docker container

Requirements

- docker
- postgres client
- awscli
- terraform
- openssl
- linux/mac

## Running test

Create `.tfbackend` file

```hcl
region = "eu-west-1"
bucket = "my-bucket-name"
key    = "terraform-aws-postgres-bootstrap/docker-init-script.tfstate"

```

- log in with awscli
- terraform init -backend-config=".tfbackend"
- terraform plan -out=tfplan
- terraform apply tfplan

## Cleaning up after test

- terraform destroy
