terraform {
  required_providers {
    multipass = {
      source = "larstobi/multipass"
    }
  }
}

resource "multipass_instance" "this" {
  name   = "kijanikiosk-${var.server_name}"
  cpus   = var.cpus
  memory = var.memory
  disk   = var.disk
  image  = var.image

  cloudinit_file = var.cloudinit_file
}