#!/usr/bin/env bash
set -euo pipefail
LAB=iac-lab
source ../common.sh
aws cloudformation delete-stack --stack-name "$LAB"
aws cloudformation wait stack-delete-complete --stack-name "$LAB"
aws ec2 delete-key-pair --key-name "$LAB" || true
rm -f "$KEY" inventory.ini
echo "cleanup done"
