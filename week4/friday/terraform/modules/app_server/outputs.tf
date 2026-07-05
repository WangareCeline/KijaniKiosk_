output "name" {
  description = "The Multipass instance name, e.g. kijanikiosk-api. pipeline.sh uses this with `multipass info` to get the real IP, since this provider's IP reporting isn't reliable enough to trust as a direct Terraform output."
  value       = multipass_instance.this.name
}
