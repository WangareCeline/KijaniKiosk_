variable "server_name" {
  description = "Logical name for this server (e.g. api, payments, logs). Used for tagging and resource naming."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type to launch (e.g. t3.micro). Kept as a variable so environments can differ without touching resource blocks."
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch the instance from. Passed in from a data source lookup in root, never hardcoded here."
  type        = string
}

variable "key_name" {
  description = "Name of the AWS key pair to attach for SSH access. Must match the private key Ansible will use to connect."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID the instance will be launched into."
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance."
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to merge onto the instance, e.g. environment or owner tags."
  type        = map(string)
  default     = {}
}
