output "databases" {
  description = "Map of database module output with each key being the name of the database created."
  value       = module.databases
}

output "users" {
  description = "Map of user module output with each key being the name of the user created."
  value       = module.users
}

output "scripts" {
  description = "Map of script module output with each key being the name of the script executed."
  value       = module.scripts
}
