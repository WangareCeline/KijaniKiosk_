terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Dynamic AMI lookup - never hardcode an AMI ID.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "kijanikiosk" {
  name        = "kijanikiosk-sg"
  description = "Allow SSH from the operator's current IP only, and all outbound traffic."
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "kijanikiosk"
  }
}

module "servers" {
  source = "./modules/app_server"
  for_each = var.servers

  server_name         = each.key
  instance_type       = var.instance_type
  ami_id              = data.aws_ami.ubuntu.id
  key_name            = var.key_name
  subnet_id           = var.subnet_id
  security_group_ids  = [aws_security_group.kijanikiosk.id]
}
