# Example for Terraform AWS Postgres Bootstrap

Example usage of the root module.

Requirements

- VPN connection to VPC on AWS
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
key    = "terraform-aws-postgres-bootstrap/rds-init.tfstate"
```

Create `.tfvars` file

```hcl
vpc_id = "vpc-xxxxxx"
db_subnet_ids = ["subnet-xxx", "subnet-yyy"]
allowed_cidrs = [
  { cidr_blocks = ["10.150.0.0/24", "10.150.1.0/24"], description = "private-subnets" },
  { cidr_blocks = ["10.190.0.0/16"], description = "vpn" } # whitelisting vpn subnet within the VPC
]
```

- turn on VPN connection to your AWS VPC
- log in with awscli
- terraform init -backend-config=".tfbackend"
- terraform plan -var-file=".tfvars" -out=tfplan
- terraform apply tfplan

## Cleaning up after test

- terraform destroy -var-file=".tfvars"
