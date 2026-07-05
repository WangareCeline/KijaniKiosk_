variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type used for all three KijaniKiosk servers."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing AWS key pair used for SSH access to all servers. Must exist in your AWS account already."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the servers. Should be your current IP with /32, not 0.0.0.0/0."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to launch the servers and security group into."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the servers into."
  type        = string
}

variable "servers" {
  description = "Map of server definitions. Key is the logical server name, used for tagging and inventory grouping."
  type        = map(object({}))
  default = {
    api      = {}
    payments = {}
    logs     = {}
  }
}
