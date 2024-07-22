module "database_credentials" {
  source = "../../../credentials/database"

  server_name     = var.conn.server_name
  environment     = var.conn.environment
  id              = var.id
  host            = var.conn.host
  port            = var.conn.port
  engine          = var.conn.engine
  database        = var.name
  user_id         = var.owner_id
  user_role       = "owner"
  master_database = false
}

resource "null_resource" "create_database" {
  triggers = {
    file_sha    = filesha256("${path.module}/sql/create_database.sh")
    creation_id = module.database_credentials.id
    owner_id    = var.owner_id
  }

  provisioner "local-exec" {
    quiet = true
    environment = {
      "PGUSER"     = var.conn.maintenance_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = var.conn.maintenance_database
    }
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    export DATABASE_NAME="${var.name}"
    export DATABASE_OWNER="${local.owner_name}"
    chmod +x ${path.module}/sql/create_database.sh
    ${path.module}/sql/create_database.sh
    EOT
  }
}

resource "null_resource" "rename_database" {
  triggers = {
    file_sha = filesha256("${path.module}/sql/rename_database.sh")
    database = var.old_name == null ? "" : var.name
  }

  provisioner "local-exec" {
    quiet = true
    environment = {
      "PGUSER"     = var.conn.maintenance_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = var.conn.maintenance_database
    }
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    if [ "${var.old_name == null ? "" : var.old_name}" = "" ]; then
      echo "Detected change in database name but old_name was not provided. Skipping database renaming."
      exit 0
    fi
    export OLD_DB_NAME="${var.old_name == null ? "" : var.old_name}"
    export NEW_DB_NAME="${var.name}"
    if [ "$OLD_DB_NAME" = "$NEW_DB_NAME" ]; then
      echo "Old database name is same as new database name. Skipping database renaming."
      exit 0
    fi
    chmod +x ${path.module}/sql/rename_database.sh
    ${path.module}/sql/rename_database.sh
    EOT
  }

  depends_on = [null_resource.create_database]
}

resource "null_resource" "create_schema" {
  for_each = local.schemas_map

  triggers = {
    file_sha = filesha256("${path.module}/sql/create_schema.sql")
    schema   = each.key
  }

  provisioner "local-exec" {
    quiet = true
    environment = {
      "PGUSER"     = var.conn.maintenance_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = var.name
    }
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    psql \
    -v ON_ERROR_STOP=1 \
    -v schema_name="${each.value}" \
    -v database_owner="${local.owner_name}" \
    -f ${path.module}/sql/create_schema.sql
    EOT
  }
  depends_on = [null_resource.create_database]
}

resource "null_resource" "create_extension" {
  for_each = local.extensions_map

  triggers = {
    file_sha  = filesha256("${path.module}/sql/create_extension.sql")
    extension = each.key
  }

  provisioner "local-exec" {
    quiet = true
    environment = {
      "PGUSER"     = var.conn.maintenance_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = var.name
    }
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    psql \
    -v ON_ERROR_STOP=1 \
    -v schema_name="${each.value.schema}" \
    -v extension_name="${each.value.name}" \
    -f ${path.module}/sql/create_extension.sql
    EOT
  }
  depends_on = [null_resource.create_schema]
}
