resource "null_resource" "user_credentials" {
  triggers = {
    # This triggers the regeneration of the password when the flag is set to true
    # It also triggers the first time the flag is set back to false, but the null resource will not generate a new password in that case
    regenerate_password = var.regenerate_password
    timestamp           = var.regenerate_password ? timestamp() : ""
    secret_name         = "${var.environment}/database-server/${var.server_name}/user/${local.id}"
    user                = var.name
    credentials_sha     = var.password == null ? null : sha256(var.password)
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<EOT
    set -e

    SECRET_EXISTS=$(
      aws secretsmanager describe-secret --secret-id "${self.triggers.secret_name}" > /dev/null 2>&1 && echo "exist" || echo "not-found"
    )
    
    if [ "${local.password_supplied}" = "false" ]; then
      PASSWORD=$(openssl rand -base64 256 | tr -dc 'A-Za-z0-9_!@#' | head -c 16)
    else
      PASSWORD='${nonsensitive(var.password == null ? "" : var.password)}'
    fi

    if [ "$SECRET_EXISTS" = "not-found" ]; then
      if [ "${local.password_supplied}" = "false" ]; then
        echo "Secret does not exist yet. Creating credentials for user ${local.id} with generated password."
      else
        echo "Secret does not exist yet. Creating credentials for user ${local.id} with supplied password."
      fi
      
      aws secretsmanager create-secret \
      --name "${self.triggers.secret_name}" \
      --description "${coalesce(var.description, "User credentials for user ${var.name} in database server ${var.server_name}.")}" \
      --secret-string "{\"username\":\"${var.name}\",\"password\":\"$PASSWORD\",\"id\":\"${local.id}\"}" \
      --tags Key=master,Value="${var.master_user ? "true" : "false"}" Key=username,Value="${var.name}" Key=server,Value="${var.server_name}" Key=environment,Value="${var.environment}" \
      > /dev/null && echo "Secret created." || (echo "Secret could not be created." && exit 1)
      
      sleep 5
      exit 0
    fi;

    if [ "${var.regenerate_password}" = "true" ] || [ "${local.password_supplied}" = "true" ] ; then
      if [ "${local.password_supplied}" = "false" ]; then
        echo "Secret already exists. Updating credentials for user ${local.id} with generated password."
      else
        echo "Secret already exists and password regeneration is enabled. Updating credentials for user ${local.id} with supplied password."
      fi

      aws secretsmanager update-secret \
      --secret-id "${self.triggers.secret_name}" \
      --description "${coalesce(var.description, "User credentials for user ${var.name} in database server ${var.server_name}.")}" \
      --secret-string "{\"username\":\"${var.name}\",\"password\":\"$PASSWORD\",\"id\":\"${local.id}\"}" \
        > /dev/null && echo "Secret updated." || (echo "Secret could not be updated." && exit 1)

      aws secretsmanager tag-resource \
      --secret-id "${self.triggers.secret_name}" \
      --tags Key=master,Value="${var.master_user ? "true" : "false"}" Key=username,Value="${var.name}" Key=server,Value="${var.server_name}" Key=environment,Value="${var.environment}" \
      > /dev/null && echo "Secret tags updated." || (echo "Secret tags could not be updated." && exit 1)
      
      sleep 5
      exit 0
    else
      echo "Secret already exists and password regeneration is not enabled. Skipping."
      exit 0
    fi
    EOT
  }
}

resource "null_resource" "delete_user_credentials_on_destroy" {
  triggers = {
    secret_name             = "${var.environment}/database-server/${var.server_name}/user/${local.id}"
    recovery_window_in_days = var.recovery_window_in_days
    creation_id             = local.id
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<EOT
      set -e

      if [ "${self.triggers.recovery_window_in_days}" = "0" ]; then
        aws secretsmanager delete-secret --secret-id "${self.triggers.secret_name}" --force-delete-without-recovery \
        > /dev/null 2>&1 && echo "Secret for user ${self.triggers.creation_id} deleted without recovery." \
        || (echo "Secret for user ${self.triggers.creation_id} could not be deleted" && exit 1)
      else
        aws secretsmanager delete-secret --secret-id "${self.triggers.secret_name}" --recovery-window-in-days ${self.triggers.recovery_window_in_days} \
        > /dev/null 2>&1 && echo "Secret for user ${self.triggers.creation_id} deleted with ${self.triggers.recovery_window_in_days} day recovery window." \
        || (echo "Secret for user ${self.triggers.creation_id} could not be deleted" && exit 1)
      fi;
    EOT
  }
}
