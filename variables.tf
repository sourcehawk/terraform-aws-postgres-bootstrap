variable "environment" {
  description = "Unique identifier for the environment. Used for tagging and naming resources."
  type        = string
}

variable "database_configs" {
  description = "The configurations of the databases to create."
  type = list(object({
    # See postgres_rds module for details on each of these configuration options
    rds = object({
      identifier                 = string
      server_name                = string
      vpc_id                     = string
      db_subnet_ids              = optional(list(string))
      snapshot_identifier        = optional(string)
      postgres_version           = string
      auto_minor_version_upgrade = optional(bool)
      instance_class             = string
      allocated_storage          = number
      storage_type               = optional(string)
      storage_encrypted          = optional(bool)
      maintenance_username       = optional(string)
      maintenance_database       = optional(string)
      subnet_group               = optional(string)
      max_allocated_storage      = optional(number)
      deletion_protection        = optional(bool)
      skip_final_snapshot        = optional(bool)
      existing_user_credentials = optional(object({
        username = string
        password = string
      }))
      regenerate_password = optional(bool)
      allowed_cidrs = optional(list(object({
        cidr_blocks = list(string)
        description = string
      })))
      parameter_group = optional(list(object({
        name         = string
        value        = string
        apply_method = string
      })))
    })
    # See postgres_init module for details on each of these configuration options
    init = object({
      users = optional(list(object({
        id                  = string,
        name                = string,
        password            = optional(string),
        regenerate_password = optional(bool)
        old_name            = optional(string)
      })))
      databases = optional(list(object({
        id       = string
        name     = string
        owner_id = string
        old_name = optional(string)
        schemas  = optional(list(string))
        extensions = optional(list(object({
          name   = string
          schema = string
        })))
      })))
      scripts = optional(list(object({
        id          = string
        script      = string
        user_id     = optional(string)
        database_id = optional(string)
        variables   = optional(map(string))
        secrets = optional(map(object(
          {
            path = string
            key  = optional(string)
          }
        )))
        shell_script             = optional(bool)
        rerun_on_user_change     = optional(bool)
        rerun_on_variable_change = optional(bool)
      })))
    })
  }))
}

locals {
  rds_instances    = [for db in var.database_configs : db.rds]
  rds_instance_map = { for db in var.database_configs : db.rds.identifier => db.rds }
  rds_init_map     = { for db in var.database_configs : db.rds.identifier => db.init }
}
