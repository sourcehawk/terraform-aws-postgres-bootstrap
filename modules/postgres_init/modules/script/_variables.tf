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
  description = "The id of the script. This is used to uniquely identify the script."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9_/\\.]+)$", var.id)) && length(var.id) <= 63 && length(var.id) >= 1
    error_message = "The id must only contain lowercase letters, numbers, underscores, forward slashes, and dots, and be less than 64 characters."
  }
}

variable "script" {
  description = "The path to the script to execute. Relative to execution directory."
  type        = string
  nullable    = false
}

variable "shell_script" {
  description = "Whether the script is a shell script or not. If not, it is assumed to be a sql script."
  type        = bool
  default     = false
  nullable    = false
}

variable "variables" {
  description = "Variables to set when executing the script. If the script is a shell script, these will be set in the shell. If the script is a sql script, these will be passed as arguments using the `-v` flag."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "secrets" {
  description = "Secrets to set when executing the script. These will be set as environment variables. The map value should be the path to the secret in aws secret manager."
  type = map(object({
    path = string,
    key  = optional(string)
  }))
  default  = {}
  nullable = false
}

variable "database_id" {
  description = "The database to execute script in. When not provided, the script will be executed in the default database."
  type        = string
  nullable    = false
  default     = "master"
}

variable "user_id" {
  description = "The user to execute script with. When not provided, the script will be executed as the master user."
  type        = string
  nullable    = false
  default     = "master"
}

variable "rerun_on_variable_change" {
  description = "Whether to rerun the script when the variables / secrets change. If set to false, the script will not be updated when it changes."
  type        = bool
  default     = false
  nullable    = false
}

variable "rerun_on_user_change" {
  description = "Whether to rerun the script when the user changes. If set to false, the script will not be updated when the user changes."
  type        = bool
  default     = false
  nullable    = false
}

locals {
  must_retrieve_user     = !(var.user_id == "master" && nonsensitive(var.conn.password) != null)
  must_retrieve_database = !(var.database_id == "master" && nonsensitive(var.conn.password) != null)
}

locals {
  secrets = {
    for k, v in var.secrets : k => (
      lookup(v, "key", null) == null
      ? nonsensitive(data.aws_secretsmanager_secret_version.secrets[k].secret_string)
      : nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.secrets[k].secret_string)[v.key])
    )
  }
  pg_user = (
    local.must_retrieve_user
    ? jsondecode(data.aws_secretsmanager_secret_version.user[0].secret_string)["username"]
    : var.conn.maintenance_user
  )
  pg_password = (
    local.must_retrieve_user
    ? nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.user[0].secret_string)["password"])
    : nonsensitive(var.conn.password)
  )
  pg_database = (
    local.must_retrieve_database
    ? jsondecode(data.aws_secretsmanager_secret_version.database[0].secret_string)["database"]
    : var.conn.maintenance_database
  )
}

locals {
  user_change = (
    nonsensitive(var.conn.password) == null
    ? data.aws_secretsmanager_secret_version.user[0].version_id
    : sha256("${local.pg_user}-${sha256(nonsensitive(var.conn.password))}")
  )
}
