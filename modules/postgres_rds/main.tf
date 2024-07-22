resource "aws_db_subnet_group" "this" {
  count       = var.subnet_group == null ? 1 : 0
  name_prefix = var.identifier
  description = "Subnet group for the ${var.identifier} ${local.db_engine} database server"
  subnet_ids  = var.db_subnet_ids
}

resource "aws_security_group" "access" {
  name_prefix = local.db_access_sg
  description = "Attaching this Security group gives access to the ${var.identifier} ${local.db_engine} database if there is *direct* network reachability."
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = local.db_access_sg
    environment = var.environment
  }
}

resource "aws_security_group_rule" "access_ingress" {
  security_group_id = aws_security_group.access.id
  description       = "Allow ${local.db_engine} port traffic"
  from_port         = local.db_port
  to_port           = local.db_port
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  type              = "ingress"
}

resource "aws_security_group_rule" "access_egress" {
  security_group_id = aws_security_group.access.id
  description       = "Allow ${local.db_engine} port traffic"
  from_port         = local.db_port
  to_port           = local.db_port
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "tcp"
  type              = "egress"
}

resource "aws_security_group" "this" {
  name_prefix = "db-${var.identifier}"
  description = "Security group applied on the ${var.identifier} ${local.db_engine} database."
  vpc_id      = var.vpc_id

  # Terraform will create the new security group and attach it to the instance 
  # before trying to destroy the existing security group. 
  # By doing this, the existing security group is detached and can be destroyed without issue.
  # We need this because otherwise we cannot delete (modify) the security group attached to the DB.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "db-${var.identifier}"
    environment = var.environment
  }
}

resource "aws_security_group_rule" "db_egress" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  protocol          = "-1"
  type              = "egress"
}

# Allow access from all db subnets
resource "aws_security_group_rule" "db_subnet_cidrs_ingress" {
  count = length(local.subnets)

  security_group_id = aws_security_group.this.id
  description       = local.subnets[count.index].name
  from_port         = local.db_port
  to_port           = local.db_port
  cidr_blocks       = [local.subnets[count.index].cidr]
  protocol          = "tcp"
  type              = "ingress"
}

# Allow access from these additional CIDRs specified by the user
resource "aws_security_group_rule" "db_custom_cidrs_ingress" {
  count = length(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  description       = var.allowed_cidrs[count.index].description
  from_port         = local.db_port
  to_port           = local.db_port
  cidr_blocks       = var.allowed_cidrs[count.index].cidr_blocks
  protocol          = "tcp"
  type              = "ingress"
}

# For anything else (not in allowed CIDRs) - attach this security group to allow access - f.x EC2 in public subnet
resource "aws_security_group_rule" "db_sg_access_ingress" {
  security_group_id = aws_security_group.this.id

  source_security_group_id = aws_security_group.access.id
  description              = "Allow access to database server from resources that have the ${aws_security_group.access.name} security group attached"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  type                     = "ingress"
}

resource "aws_iam_role" "monitoring" {
  name_prefix = var.identifier
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name        = "db-monitoring-${var.identifier}"
    environment = var.environment
  }
}

resource "aws_db_parameter_group" "this" {
  description = "Parameter group for the ${var.identifier} ${local.db_engine} database"
  name_prefix = var.identifier
  family      = "${local.db_engine}${split(".", var.postgres_version)[0]}"

  dynamic "parameter" {
    for_each = var.parameter_group

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = var.identifier
    environment = var.environment
  }
}

resource "random_string" "postfix" {
  length  = 8
  special = false
  numeric = false
}

# Use a different resource if user already exists so that the database
# doesn't depend on non existing secret when importing databases with 
# credentials that haven't been created by Terraform
module "existing_user_credentials" {
  count  = var.existing_user_credentials == null ? 0 : 1
  source = "../credentials/user"

  server_name             = var.server_name
  environment             = var.environment
  name                    = var.existing_user_credentials.username
  password                = var.existing_user_credentials.password
  recovery_window_in_days = 0
  master_user             = true
}

module "user_credentials" {
  count  = var.existing_user_credentials == null ? 1 : 0
  source = "../credentials/user"

  server_name             = var.server_name
  environment             = var.environment
  name                    = var.maintenance_username
  recovery_window_in_days = var.deletion_protection ? 30 : 0
  regenerate_password     = var.regenerate_password
  master_user             = true

  # Make sure the old credentials are destroyed before the new ones are created
  # We need this because both secrets are using the same name and conflict with each other.
  depends_on = [module.existing_user_credentials]
}

resource "aws_db_instance" "this" {
  identifier          = var.identifier
  snapshot_identifier = var.snapshot_identifier

  db_name        = var.maintenance_database
  username       = var.existing_user_credentials == null ? var.maintenance_username : var.existing_user_credentials.username
  password       = "temporary-password" # This will be updated by the null_resource
  port           = local.db_port
  engine         = local.db_engine
  engine_version = var.postgres_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.identifier}-final-${random_string.postfix.result}"
  backup_retention_period   = 30

  parameter_group_name   = aws_db_parameter_group.this.name
  db_subnet_group_name   = var.subnet_group == null ? aws_db_subnet_group.this[0].name : var.subnet_group
  vpc_security_group_ids = [aws_security_group.this.id]

  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.monitoring.arn
  performance_insights_enabled = true

  copy_tags_to_snapshot       = true
  storage_encrypted           = var.storage_encrypted # Backwards compatibility (should be true)
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  apply_immediately           = true
  allow_major_version_upgrade = true

  # This must be disabled first before deleting.
  deletion_protection = var.deletion_protection

  tags = {
    Name        = "${var.identifier}"
    environment = var.environment
  }

  lifecycle {
    ignore_changes = [password]
  }

  # depends on so that the password is deleted **after** the database is deleted.
  depends_on = [module.user_credentials]
}

resource "null_resource" "update_master_password" {
  triggers = {
    # This triggers the regeneration of the password when the flag is set to true
    # It also triggers the first time the flag is set back to false, but has no effect
    regenerate_password = var.regenerate_password
    timestamp           = var.regenerate_password ? timestamp() : ""
    password_sha        = sha256(local.master_password)
  }

  provisioner "local-exec" {
    quiet = true
    environment = {
      "PGUSER"     = aws_db_instance.this.username
      "PGHOST"     = aws_db_instance.this.address
      "PGPORT"     = aws_db_instance.this.port
      "PGDATABASE" = aws_db_instance.this.db_name
    }
    command = <<EOT
    set -e

    wait_for_available() {
      local db_instance_identifier=$1

      echo "Waiting for the RDS instance to be in an available state..."

      while true; do
        status=$(aws rds describe-db-instances --db-instance-identifier "$db_instance_identifier" --query "DBInstances[0].DBInstanceStatus" --output text)
        if [ "$status" = "available" ]; then
          break
        fi
        echo "Current status: $status. Waiting for 10 seconds..."
        sleep 10
      done

      echo "RDS instance is now available."
    }

    wait_for_available ${aws_db_instance.this.identifier}

    aws rds modify-db-instance \
    --db-instance-identifier ${aws_db_instance.this.identifier} \
    --master-user-password '${local.master_password}' \
    --apply-immediately > /dev/null && echo "Master password updated." || (echo "Master password could not be updated." && exit 1)

    wait_for_available ${aws_db_instance.this.identifier}

    export PGPASSWORD='${sensitive(local.master_password)}'

    # Wait for the password change to take effect
    attempts=0
    max_attempts=20
    success=false

    while [ $attempts -lt $max_attempts ]; do
      psql -c "SELECT 1" && success=true && break
      attempts=$((attempts + 1))
      echo "Password verification $attempts/$max_attempts failed. Retrying in 10 seconds..."
      sleep 10
    done

    if [ "$success" = true ]; then
      echo "Password change verified successfully."
    else
      echo "Failed to verify password change after $max_attempts attempts."
      exit 1
    fi
    EOT
  }

  depends_on = [module.user_credentials, module.existing_user_credentials, aws_db_instance.this]
}

module "database_credentials" {
  source = "../credentials/database"

  server_name     = var.server_name
  environment     = var.environment
  host            = aws_db_instance.this.address
  port            = aws_db_instance.this.port
  engine          = aws_db_instance.this.engine
  database        = aws_db_instance.this.db_name
  user_id         = "master"
  user_role       = "owner"
  master_database = true

  depends_on = [aws_db_instance.this, module.user_credentials, module.existing_user_credentials]
}
