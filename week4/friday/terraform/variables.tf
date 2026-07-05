variable "cpus" {
  description = "Number of vCPUs per server."
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory per server, e.g. '1G'."
  type        = string
  default     = "1G"
}

variable "disk" {
  description = "Disk space per server, e.g. '5G'."
  type        = string
  default     = "5G"
}

variable "image" {
  description = "Ubuntu image/release for all servers."
  type        = string
  default     = "22.04"
}

variable "ssh_public_key_path" {
  description = "Path to the operator's SSH public key, injected into each VM via cloud-init so Ansible can connect."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
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
