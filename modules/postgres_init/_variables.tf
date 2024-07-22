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

variable "users" {
  description = "A list of users to create. See the `user` module for more information. Executed first."
  type = list(object({
    id                  = string,
    name                = string,
    password            = optional(string),
    regenerate_password = optional(bool),
    old_name            = optional(string),
  }))
  default  = []
  nullable = false
}

variable "databases" {
  description = "A list of databases to create. See the `database` module for more information. Executed after users are created."
  type = list(object({
    id       = string
    name     = string
    owner_id = string
    old_name = optional(string)
    schemas  = optional(list(string))
    extensions = optional(list(object({
      name   = string
      schema = string
    })))
  }))
  default  = []
  nullable = false
}

variable "scripts" {
  description = "A list of scripts to run. See the `script` module for more information. Executed after users and databases are created."
  type = list(object({
    id          = string
    script      = string
    user_id     = optional(string)
    database_id = optional(string)
    variables   = optional(map(string))
    secrets = optional(map(object({
      path = string
      key  = optional(string)
    })))
    shell_script             = optional(bool)
    rerun_on_user_change     = optional(bool)
    rerun_on_variable_change = optional(bool)
  }))
  default  = []
  nullable = false
}

locals {
  user_map   = { for user in var.users : user.id => user }
  db_map     = { for db in var.databases : db.id => db }
  script_map = { for script in var.scripts : script.id => script }
}
