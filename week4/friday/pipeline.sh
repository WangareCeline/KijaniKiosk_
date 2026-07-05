#!/bin/bash
# pipeline.sh - Runs the full KijaniKiosk IaC pipeline in sequence:
# Terraform provisions three Multipass VMs, then their real IPs are
# extracted and written into the Ansible inventory, then Ansible
# configures all three servers to Week 3 standards.
#
# Usage: ./pipeline.sh
#
# Exits non-zero if either Terraform or Ansible fails (set -e handles this
# for every command below; PIPESTATUS check on the ansible-playbook call
# catches failures even though its output is piped through `tee`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.ini"

echo "=================================================================="
echo "STEP 1: Terraform apply"
echo "=================================================================="
cd "$TERRAFORM_DIR"
terraform apply -auto-approve

echo ""
echo "=================================================================="
echo "STEP 2: Extract server IPs from Multipass and write Ansible inventory"
echo "=================================================================="
API_IP=$(multipass info kijanikiosk-api | grep IPv4 | awk '{print $2}')
PAYMENTS_IP=$(multipass info kijanikiosk-payments | grep IPv4 | awk '{print $2}')
LOGS_IP=$(multipass info kijanikiosk-logs | grep IPv4 | awk '{print $2}')

if [[ -z "$API_IP" || -z "$PAYMENTS_IP" || -z "$LOGS_IP" ]]; then
  echo "ERROR: Failed to extract one or more server IPs from Multipass." >&2
  exit 1
fi

cat > "$INVENTORY_FILE" << EOF
[kijanikiosk]
api      ansible_host=$API_IP
payments ansible_host=$PAYMENTS_IP
logs     ansible_host=$LOGS_IP
EOF

echo "Inventory written to $INVENTORY_FILE:"
cat "$INVENTORY_FILE"

echo ""
echo "=================================================================="
echo "STEP 3: Ansible playbook run"
echo "=================================================================="
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory.ini kijanikiosk.yml

echo ""
echo "Pipeline completed successfully."
