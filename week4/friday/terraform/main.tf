terraform {
  required_version = ">= 1.5.0"
  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "multipass" {}

# Renders a cloud-init file that injects the operator's SSH public key into
# the default 'ubuntu' user, so Ansible can connect over SSH without any
# manual key copying into the VM after it boots.
resource "local_file" "cloud_init" {
  filename = "${path.module}/generated-cloud-init.yaml"
  content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

module "servers" {
  source   = "./modules/app_server"
  for_each = var.servers

  server_name    = each.key
  cpus           = var.cpus
  memory         = var.memory
  disk           = var.disk
  image          = var.image
  cloudinit_file = local_file.cloud_init.filename
}
