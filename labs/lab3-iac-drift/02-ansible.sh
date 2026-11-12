#!/usr/bin/env bash
# Builds the inventory from the stack outputs, then applies the playbook.
set -euo pipefail
LAB=iac-lab
source ../common.sh
out() { aws cloudformation describe-stacks --stack-name "$LAB" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
W1=$(out Web1Ip); W2=$(out Web2Ip)
printf '[web]\nweb1 ansible_host=%s\nweb2 ansible_host=%s\n' "$W1" "$W2" > inventory.ini
until ansible web -m ping >/dev/null 2>&1; do echo "waiting for SSH..."; sleep 5; done
ansible-playbook site.yml
curl -s "http://$W1/"; curl -s "http://$W2/"
