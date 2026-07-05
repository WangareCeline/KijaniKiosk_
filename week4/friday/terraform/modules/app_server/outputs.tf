output "public_ip" {
  description = "Public IP address of this server, used to build the Ansible inventory."
  value       = aws_instance.this.public_ip
}

output "instance_id" {
  description = "EC2 instance ID, useful for debugging and destroy verification."
  value       = aws_instance.this.id
}
