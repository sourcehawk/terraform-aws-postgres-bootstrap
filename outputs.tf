output "postgres_instances" {
  description = "Map of postgres_rds module output with each key being the identifier of the RDS instance created."
  value       = module.postgres_rds
}

output "postgres_inits" {
  description = "Map of postgres_init module output with each key being the identifier of the RDS instance it was executed on."
  value       = module.postgres_init
}
