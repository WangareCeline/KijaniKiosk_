output "server_names" {
  description = "Map of logical server name to Multipass instance name. pipeline.sh loops over this and calls `multipass info <name>` to get each real IP for the Ansible inventory."
  value = {
    for name, srv in module.servers : name => srv.name
  }
}
