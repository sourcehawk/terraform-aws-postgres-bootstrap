resource "null_resource" "database_credentials" {
  triggers = {
    secret_name            = "${var.environment}/database-server/${var.server_name}/database/${local.id}/credentials"
    user_secret_version_id = data.aws_secretsmanager_secret_version.user.version_id
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<EOT
      set -e

      SECRET_EXISTS=$(
        aws secretsmanager describe-secret --secret-id "${self.triggers.secret_name}" > /dev/null 2>&1 && echo "exist" || echo "not-found"
      )

      PASSWORD=${local.database_password}

      if [ "$SECRET_EXISTS" = "not-found" ]; then
        echo "Database credential secret for database ${local.id} does not exist yet. Creating credentials."
        
        aws secretsmanager create-secret \
        --name "${self.triggers.secret_name}" \
        --description "Database connection credentials for ${var.database} in database server ${var.server_name}." \
        --secret-string "{\"host\":\"${var.host}\",\"port\":\"${var.port}\",\"database\":\"${var.database}\",\"engine\":\"${var.engine}\",\"username\":\"${var.database}\",\"password\":\"$PASSWORD\",\"id\":\"${local.id}\"}" \
        --tags Key=role,Value="${var.user_role}" Key=database,Value="${var.database}" Key=server,Value="${var.server_name}" Key=environment,Value="${var.environment}" \
        > /dev/null && echo "Secret created." || (echo "Secret could not be created." && exit 1)

      else
        echo "Database credential secret for database ${local.id} already exists. Updating credentials."

        aws secretsmanager update-secret \
        --secret-id "${self.triggers.secret_name}" \
        --description "Database connection credentials for ${var.database} in database server ${var.server_name}." \
        --secret-string "{\"host\":\"${var.host}\",\"port\":\"${var.port}\",\"database\":\"${var.database}\",\"engine\":\"${var.engine}\",\"username\":\"${var.database}\",\"password\":\"$PASSWORD\",\"id\":\"${local.id}\"}" \
        > /dev/null && echo "Secret updated." || (echo "Secret could not be updated." && exit 1)
        
        aws secretsmanager tag-resource \
        --secret-id "${self.triggers.secret_name}" \
        --tags Key=role,Value="${var.user_role}" Key=database,Value="${var.database}" Key=server,Value="${var.server_name}" Key=environment,Value="${var.environment}" \
        > /dev/null && echo "Secret tags updated." || (echo "Secret tags could not be updated." && exit 1)
        
      fi;

      sleep 5
    EOT
  }
}

resource "null_resource" "delete_database_credentials_on_destroy" {
  triggers = {
    secret_name = "${var.environment}/database-server/${var.server_name}/database/${local.id}/credentials"
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<EOT
      set -e

      aws secretsmanager delete-secret --secret-id "${self.triggers.secret_name}" --force-delete-without-recovery \
      > /dev/null 2>&1 && echo "Secret deleted without recovery." || (echo "Secret could not be deleted" && exit 1)
    EOT
  }
}
