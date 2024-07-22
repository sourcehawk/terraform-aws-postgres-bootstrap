module "users" {
  source   = "./modules/user"
  for_each = local.user_map

  conn                = var.conn
  id                  = each.key
  name                = each.value.name
  password            = each.value.password
  regenerate_password = each.value.regenerate_password
  old_name            = each.value.name
}

module "databases" {
  source   = "./modules/database"
  for_each = local.db_map

  conn       = var.conn
  id         = each.key
  name       = each.value.name
  old_name   = each.value.old_name
  owner_id   = each.value.owner_id
  schemas    = each.value.schemas
  extensions = each.value.extensions

  depends_on = [module.users]
}

module "scripts" {
  source   = "./modules/script"
  for_each = local.script_map

  conn                     = var.conn
  id                       = each.key
  script                   = each.value.script
  user_id                  = each.value.user_id
  database_id              = each.value.database_id
  variables                = each.value.variables
  secrets                  = each.value.secrets
  shell_script             = each.value.shell_script
  rerun_on_user_change     = each.value.rerun_on_user_change
  rerun_on_variable_change = each.value.rerun_on_variable_change

  depends_on = [module.databases]
}
