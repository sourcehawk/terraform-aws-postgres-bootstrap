module "postgres_rds" {
  for_each = local.rds_instance_map
  source   = "./modules/postgres_rds"

  vpc_id        = each.value.vpc_id
  db_subnet_ids = each.value.db_subnet_ids

  identifier  = each.key
  server_name = each.value.server_name
  environment = var.environment

  snapshot_identifier        = each.value.snapshot_identifier
  postgres_version           = each.value.postgres_version
  auto_minor_version_upgrade = each.value.auto_minor_version_upgrade
  instance_class             = each.value.instance_class
  storage_type               = each.value.storage_type
  allocated_storage          = each.value.allocated_storage
  maintenance_database       = each.value.maintenance_database
  maintenance_username       = each.value.maintenance_username
  max_allocated_storage      = each.value.max_allocated_storage
  skip_final_snapshot        = each.value.skip_final_snapshot
  deletion_protection        = each.value.deletion_protection
  subnet_group               = each.value.subnet_group
  storage_encrypted          = each.value.storage_encrypted

  allowed_cidrs             = each.value.allowed_cidrs
  existing_user_credentials = each.value.existing_user_credentials
  regenerate_password       = each.value.regenerate_password
  parameter_group           = each.value.parameter_group
}

module "postgres_init" {
  source   = "./modules/postgres_init"
  for_each = local.rds_init_map

  conn = {
    server_name = local.rds_instance_map[module.postgres_rds[each.key].rds_instance.identifier].server_name
    environment = var.environment
    engine      = module.postgres_rds[each.key].rds_instance.engine
    host        = module.postgres_rds[each.key].rds_instance.address
    port        = module.postgres_rds[each.key].rds_instance.port
    maintenance_user = (
      local.rds_instance_map[each.key].existing_user_credentials == null
      ? module.postgres_rds[each.key].rds_instance.username
      : local.rds_instance_map[each.key].existing_user_credentials.username
    )
    password = (
      local.rds_instance_map[each.key].existing_user_credentials == null
      ? null
      : local.rds_instance_map[each.key].existing_user_credentials.password
    )
    maintenance_database = module.postgres_rds[each.key].rds_instance.db_name
  }
  users     = local.rds_init_map[each.key].users
  databases = local.rds_init_map[each.key].databases
  scripts   = local.rds_init_map[each.key].scripts

  depends_on = [module.postgres_rds]
}
