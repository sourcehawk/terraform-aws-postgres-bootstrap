variable "server_name" {
  description = "The of the server. Unique per environment. Used for grouping credentials in AWS Secrets Manager. (<environment>/database-server/<server_name)>/...)"
  type        = string
  nullable    = false
}

variable "environment" {
  description = "The environment to create the credentials in."
  type        = string
  nullable    = false
}

variable "master_database" {
  description = "Whether the database is the master database."
  type        = bool
  nullable    = false
}

variable "id" {
  description = "The id of the database to create credentials for. Used in secret name."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.id == null ? true : can(regex("^([a-z0-9_]+)$", var.id)) && length(var.id) <= 63 && length(var.id) >= 1
    error_message = "The id must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
  validation {
    condition     = ((var.id == null || var.id == "master") && var.master_database) || (!var.master_database && var.id != null)
    error_message = "The id must be null or set to 'master' when the database is the master database. Otherwise, the id must be set."
  }
  validation {
    condition     = (var.id != "master" && !var.master_database) || var.master_database
    error_message = "The id must not be set to 'master' when the database is not master database."
  }
}

variable "host" {
  description = "The host of the database server."
  type        = string
  nullable    = false
}

variable "port" {
  description = "The port of the database server."
  type        = number
  nullable    = false
}

variable "database" {
  description = "The name of the database"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.database)) && length(var.database) <= 63
    error_message = "The name must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "user_id" {
  description = "The id of the existing database user to use for the connection credentials."
  type        = string
  nullable    = false
}

variable "user_role" {
  description = "A description of the role of the user in the given database (f.x owner / user). Used for tagging."
}

variable "engine" {
  description = "The engine of the database server."
  type        = string
  nullable    = false
  default     = "postgres"
}

locals {
  id                = var.id == null ? "master" : var.id
  database_password = sensitive(jsondecode(data.aws_secretsmanager_secret_version.user.secret_string)["password"])
}
