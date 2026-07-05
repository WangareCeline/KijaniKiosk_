output "server_ips" {
  description = "Map of server name to public IP, used by pipeline.sh to build the Ansible inventory."
  value = {
    for name, srv in module.servers : name => srv.public_ip
  }
}

output "api_server_ip" {
  description = "Public IP of the api server. Named individually so pipeline.sh can extract it with -raw."
  value       = module.servers["api"].public_ip
}

output "payments_server_ip" {
  description = "Public IP of the payments server."
  value       = module.servers["payments"].public_ip
}

output "logs_server_ip" {
  description = "Public IP of the logs server."
  value       = module.servers["logs"].public_ip
}

output "ssh_commands" {
  description = "Ready-to-copy SSH commands for manual connectivity verification (Challenge C)."
  value = {
    for name, srv in module.servers :
    name => "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${srv.public_ip}"
  }
}
