variable "server_name" {
  description = "Logical name for this server (e.g. api, payments, logs). Used to build the instance name and for tagging in the Ansible inventory."
  type        = string
}

variable "cpus" {
  description = "Number of virtual CPUs to allocate to the instance."
  type        = number
  default     = 1
}

variable "memory" {
  description = "Amount of memory to allocate, e.g. '1G'."
  type        = string
  default     = "1G"
}

variable "disk" {
  description = "Amount of disk space to allocate, e.g. '5G'."
  type        = string
  default     = "5G"
}

variable "image" {
  description = "Ubuntu image/release to launch, e.g. '22.04'. Declared as a variable so it is never hardcoded in the resource block."
  type        = string
  default     = "22.04"
}

variable "cloudinit_file" {
  description = "Path to a rendered cloud-init file that injects the operator's SSH public key, so Ansible can connect without manual key copying."
  type        = string
}
