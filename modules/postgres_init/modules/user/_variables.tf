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
  nullable  = false
  sensitive = false
}

variable "id" {
  description = "A unique identifier for the user resource. It is used to identify whether the user was renamed or not so that the correct SQL can be executed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.id)) && length(var.id) <= 63 && length(var.id) >= 1
    error_message = "The id must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "name" {
  description = "The user to create in the rds instance. Credentials for the user are stored in a secret in AWS Secrets Manager. If this user has been created by a different resource, the creation will fail before any code is executed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.name)) && length(var.name) <= 63 && length(var.name) >= 1
    error_message = "The name must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "old_name" {
  description = "The old username of the user. Required when the username is changed in order to update the user in the database."
  type        = string
  default     = null
  nullable    = true
}

variable "password" {
  description = "The password for the user. Leave unfilled or null to generate a random password. The generated password will not be stored in the state file."
  type        = string
  nullable    = true
  sensitive   = true
  default     = null
}

variable "regenerate_password" {
  description = "When set to true, the password will be regenerated. Cannot be set to true when a password is being supplied."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = (var.regenerate_password && var.password == null) || !var.regenerate_password
    error_message = "Cannot regenerate the password when a password is being supplied."
  }
}

locals {
  pg_password = (nonsensitive(var.conn.password) == null
    ? nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.superuser[0].secret_string)["password"])
    : nonsensitive(var.conn.password)
  )
  user_password = (var.password == null
    ? nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.user.secret_string)["password"])
    : var.password
  )
}
