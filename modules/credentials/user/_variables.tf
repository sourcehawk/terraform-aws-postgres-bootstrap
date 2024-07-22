variable "server_name" {
  description = "The name of the database server to create credentials for. This is used to group the credentials in AWS Secrets Manager."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "The environment to create the credentials in. This is used to group the credentials in AWS Secrets Manager."
  type        = string
  nullable    = false
}

variable "master_user" {
  description = "Whether the user is the master user of the database server instance. If true, the user id will be set to 'master'."
  type        = bool
  nullable    = false
}

variable "id" {
  description = "The id of the user to create credentials for. Used in secret name."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.id == null ? true : can(regex("^([a-z0-9_]+)$", var.id)) && length(var.id) <= 63 && length(var.id) >= 1
    error_message = "The id must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
  validation {
    condition     = ((var.id == null || var.id == "master") && var.master_user) || (!var.master_user && var.id != null)
    error_message = "The id must be null or set to 'master' when the user is the master user. Otherwise, the id must be set."
  }
  validation {
    condition     = (var.id != "master" && !var.master_user) || var.master_user
    error_message = "The id must not be set to 'master' when the database is not master database."
  }
}

variable "name" {
  description = "The database user name to create credentials for. The credentials are stored in a secret in AWS Secrets Manager."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_]+)$", var.name)) && length(var.name) <= 63
    error_message = "The name must only contain lowercase letters, numbers, and underscores and be less than 64 characters."
  }
}

variable "password" {
  description = "The password for the user. Leave empty to generate a random password."
  type        = string
  nullable    = true
  sensitive   = true
  default     = null

  validation {
    condition     = var.password == null ? true : length(var.password) <= 64 && length(var.password) >= 6
    error_message = "The password must be between 6 and 64 characters long, if provided."
  }
}

variable "recovery_window_in_days" {
  description = "The number of days that Secrets Manager waits before it can delete the secret."
  type        = number
  default     = 0
  nullable    = false
}

variable "description" {
  description = "A description of the created secret."
  type        = string
  default     = null
  nullable    = true
}

variable "regenerate_password" {
  description = "When set to true, the password will be regenerated. Note that when you turn the flag to false, terraform reports that the resource needs to be updated but the null resource will not generate a new password."
  type        = bool
  default     = false
  nullable    = false
}

locals {
  id                = var.id == null ? "master" : var.id
  password_supplied = nonsensitive(var.password == null ? "false" : "true")
}
