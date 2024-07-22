variable "conn" {
  description = "The connection to the database server."
  type = object({
    server_name          = string
    environment          = string
    host                 = string
    port                 = number
    engine               = string
    maintenance_database = string
    maintenance_user     = string
    password             = optional(string)
  })
  nullable = false
}

variable "id" {
  description = "A unique identifier for the database resource. It is used to identify whether the database was renamed or not so that the correct SQL can be executed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.id)) && length(var.id) <= 63 && length(var.id) >= 1
    error_message = "The id must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "name" {
  description = "The name of the database to create."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.name)) && length(var.name) <= 63 && length(var.name) >= 1
    error_message = "The name must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "old_name" {
  description = "The old name of the database. Required when the name is changed in order to update the database in the database server."
  type        = string
  default     = null
  nullable    = true
}

variable "owner_id" {
  description = "The id of the user that shall own the database."
  type        = string
  nullable    = false
}

variable "schemas" {
  description = "The schemas to create in the database. The 'public' schema exists by default. Created with rds master user."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "extensions" {
  description = "The extensions to create in the database. Created with rds master user."
  type = list(object({
    name   = string
    schema = string
  }))
  default  = []
  nullable = false
}

locals {
  owner_name     = jsondecode(data.aws_secretsmanager_secret_version.owner.secret_string)["username"]
  extensions_map = { for ext in var.extensions : "${ext.name}@${ext.schema}" => ext }
  schemas_map    = { for schema in var.schemas : schema => schema }
  pg_password = (sensitive(var.conn.password) == null
    ? sensitive(jsondecode(data.aws_secretsmanager_secret_version.superuser[0].secret_string)["password"])
    : sensitive(var.conn.password)
  )
}
