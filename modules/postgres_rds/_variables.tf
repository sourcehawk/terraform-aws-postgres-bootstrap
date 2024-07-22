variable "environment" {
  description = "The name of environment to create the RDS instance in. Used for grouping credentials in AWS Secrets Manager. (<environment>/database-server/<identifier)>/...)"
  type        = string
  nullable    = false
}

variable "identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
  nullable    = false
}

variable "server_name" {
  description = "The name for the server. Unique per environment. Used for grouping credentials in AWS Secrets Manager. (<environment>/database-server/<server_name)>/...)"
  type        = string
  nullable    = false
}

variable "snapshot_identifier" {
  description = "The identifier of the DB snapshot to restore from"
  type        = string
  default     = null
  nullable    = true
}

variable "existing_user_credentials" {
  description = "Existing user credential for the RDS instance default user. (When importing an existing RDS instance)"
  type = object({
    username = string
    password = string
  })
  default   = null
  sensitive = true
  nullable  = true
}

variable "vpc_id" {
  description = "The VPC id used to infer the DB subnet from"
  nullable    = false
}

variable "db_subnet_ids" {
  description = "The subnet ids to use for the DB. (Subnet group will be created from these)"
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = var.subnet_group == null && length(var.db_subnet_ids) > 0
    error_message = "At least one subnet id must be provided when no pre-existing subnet group is specified."
  }
}

variable "regenerate_password" {
  description = "Whether to regenerate the password for the master user"
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = (var.regenerate_password == true && var.existing_user_credentials == null) || var.regenerate_password == false
    error_message = "Cannot regenerate password when existing_user_credentials is set. You can remove the existing_credentials after first apply to allow the module to generate new ones."
  }
}

# ------------------------------------------
# Database configuration
# ------------------------------------------

variable "postgres_version" {
  description = "The version of postgres (f.x 16 / 16.3)"
  type        = string
  nullable    = false
}

variable "auto_minor_version_upgrade" {
  description = "Whether to allow minor version upgrades automatically"
  type        = bool
  default     = true
  nullable    = false

  validation {
    condition     = !(var.auto_minor_version_upgrade && can(regex("^[0-9]+\\.[0-9]+$", var.postgres_version)))
    error_message = "Cannot enable auto_minor_version_upgrade when postgres_version is specified with a minor version."
  }
}

variable "instance_class" {
  description = "The instance class of the RDS instance (f.x db.t2.micro)"
  type        = string
  nullable    = false
}

variable "maintenance_database" {
  description = "The name of the maintenance database to create when the DB instance is created. If this parameter isn't specified, a database named 'postgres' is created in the DB instance."
  type        = string
  default     = null
  nullable    = true
}

variable "maintenance_username" {
  description = "The username of the postgres 'superuser'"
  type        = string
  default     = "postgres"
  nullable    = false
}

variable "storage_type" {
  description = "The storage type to use for the RDS instance. Default is gp3."
  type        = string
  default     = "gp3"
  nullable    = false
}

variable "allocated_storage" {
  description = "The amount of storage to allocate to the RDS instance in GB"
  type        = number
  default     = 50
  nullable    = false
}

variable "max_allocated_storage" {
  description = "The maximum amount of storage to allocate to th RDS instance in GB. When left empty, no limit is set."
  type        = number
  default     = null
  nullable    = true
}

variable "deletion_protection" {
  description = "Must be set to false before deleting the RDS instance."
  type        = bool
  default     = true
  nullable    = false
}

variable "storage_encrypted" {
  description = "Whether store is to be encrypted or not"
  type        = bool
  default     = true
  nullable    = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when deleting the RDS instance"
  type        = bool
  default     = false
  nullable    = false
}

variable "allowed_cidrs" {
  description = "A list of CIDRs to allow access to the RDS instance."
  type = list(object({
    cidr_blocks = list(string)
    description = string
  }))
  nullable = false
  default  = []
}

variable "subnet_group" {
  description = "The name of the DB subnet group to associate with the RDS instance. Will be created from variable db_subnet_ids if not set."
  type        = string
  default     = null
  nullable    = true
}

variable "parameter_group" {
  description = "A parameter group to attach to the RDS instance"
  type = list(
    object({
      name         = string
      value        = string
      apply_method = string
    })
  )
  default  = []
  nullable = false
}

locals {
  db_engine    = "postgres"
  db_port      = 5432
  db_access_sg = "db-access-${var.identifier}"
  subnets = length(var.db_subnet_ids) == 0 ? [] : [
    for s in data.aws_subnet.db_subnets : {
      name = "subnet ${lookup(s.tags, "Name", s.id)}",
      cidr = s.cidr_block
    }
  ]
  master_password = (
    var.existing_user_credentials == null
    ? nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.master.secret_string)["password"])
    : var.existing_user_credentials.password
  )
}
