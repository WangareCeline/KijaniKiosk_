# Environment Setup

This document records the exact tool stack used to build and run the KijaniKiosk
Week 4 Friday IaC pipeline, so the setup can be reproduced by another engineer.

**Path used:** Multipass (primary path), not the optional cloud path.

## Host machine

| Tool | Version |
|---|---|
| OS | Ubuntu 26.04 LTS (Surface Laptop) |
| Terraform | v1.15.7 |
| Multipass | 1.16.3 |
| Docker | 29.3.1 (used to run MinIO) |
| Ansible core | 2.21.1 |
| Python (Ansible control node) | 3.14.4 |

## Remote state backend

MinIO `RELEASE.2025-09-07T16-13-09Z`, run as a Docker container (`minio/minio`),
exposing the S3-compatible API on port 9000 and the web console on port 9001.
State is stored in a bucket named `kijanikiosk-tfstate`.

## Provisioned servers

Three Multipass instances, each running Ubuntu 22.04 LTS:

| Server | Role | Port |
|---|---|---|
| kijanikiosk-api | API service | 3000 |
| kijanikiosk-payments | Payments service (hardened, target score < 2.5) | 3001 |
| kijanikiosk-logs | Log aggregation service | 3002 |

## Ansible collections

Installed via `ansible-galaxy collection install -r requirements.yml`:
- `community.general` (ufw module)
- `ansible.posix` (acl module)

## Terraform providers

- `larstobi/multipass` ~> 1.4 (manages the three VMs)
- `hashicorp/local` ~> 2.4 (renders the cloud-init file that injects the
  operator's SSH public key into each VM)
