module "user_credentials" {
  source = "../../../credentials/user"

  server_name             = var.conn.server_name
  environment             = var.conn.environment
  id                      = var.id
  name                    = var.name
  password                = var.password
  regenerate_password     = var.regenerate_password
  recovery_window_in_days = 0
  master_user             = false
}


resource "null_resource" "update_username" {
  triggers = {
    file_sha = filesha256("${path.module}/sql/update_username.sh")
    username = var.old_name == null ? "" : var.name
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
    if [ "${var.old_name == null ? "" : var.old_name}" = "" ]; then
      echo "Detected change in username but old_name was not provided. Skipping user renaming."
      exit 0
    fi
    export PGPASSWORD='${nonsensitive(local.pg_password)}'
    export NEW_USERNAME=${var.name}
    export OLD_USERNAME=${var.old_name == null ? "" : var.old_name}
    if [ "$NEW_USERNAME" = "$OLD_USERNAME" ]; then
      echo "Old username is same as new username. Skipping user renaming."
      exit 0
    fi
    echo "Updating username from $OLD_USERNAME to $NEW_USERNAME"
    chmod +x ${path.module}/sql/update_username.sh
    ${path.module}/sql/update_username.sh
    EOT
  }
  depends_on = [module.user_credentials]
}

resource "null_resource" "create_user_or_update_password" {
  triggers = {
    file_sha         = filesha256("${path.module}/sql/create_user.sh")
    user_creation_id = module.user_credentials.id
    password_sha     = sha256(local.user_password)
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
    export PGPASSWORD='${nonsensitive(local.pg_password)}'
    export USERNAME=${var.name}
    export PASSWORD='${nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.user.secret_string)["password"])}'
    chmod +x ${path.module}/sql/create_user.sh
    ${path.module}/sql/create_user.sh
    EOT
  }
  # Must run after the username is updated so that a new user is not created with the old username 
  # when the password and username are being changed at the same time
  depends_on = [null_resource.update_username]
}
