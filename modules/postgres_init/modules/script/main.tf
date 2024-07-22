resource "null_resource" "shell_script" {
  count = var.shell_script ? 1 : 0

  triggers = {
    file_sha        = filesha256("${var.script}")
    id              = var.id
    user_change     = var.rerun_on_user_change ? local.user_change : null
    secret_change   = var.rerun_on_variable_change ? sha256(jsonencode(local.secrets)) : null
    variable_change = var.rerun_on_variable_change ? sha256(jsonencode(var.variables)) : null
  }

  provisioner "local-exec" {
    quiet = true
    environment = merge(var.variables, local.secrets, {
      "PGUSER"     = local.pg_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = local.pg_database
    })
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    chmod +x ${var.script}
    ${var.script}
    EOT
  }
}

resource "null_resource" "sql_script" {
  count = var.shell_script ? 0 : 1

  triggers = {
    file_sha        = filesha256("${var.script}")
    id              = var.id
    user_change     = var.rerun_on_user_change ? local.user_change : null
    secret_change   = var.rerun_on_variable_change ? sha256(jsonencode(local.secrets)) : null
    variable_change = var.rerun_on_variable_change ? sha256(jsonencode(var.variables)) : null
  }

  provisioner "local-exec" {
    environment = {
      "PGUSER"     = local.pg_user
      "PGHOST"     = var.conn.host
      "PGPORT"     = var.conn.port
      "PGDATABASE" = local.pg_database
    }
    command = <<EOT
    set -e
    export PGPASSWORD='${sensitive(local.pg_password)}'
    psql \
    -v ON_ERROR_STOP=1 \
    %{~for v in keys(var.variables)~}
    -v ${v}="${var.variables[v]}" \
    %{~endfor~}
    %{~for v in keys(local.secrets)~}
    -v ${v}="${local.secrets[v]}" \
    %{~endfor~}  
    -f ${path.root}/${var.script}
    EOT
  }
}

