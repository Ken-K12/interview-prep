#!/usr/bin/env bash
# Creates the key pair and deploys the CloudFormation stack.
set -euo pipefail
LAB=iac-lab
source ../common.sh
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

aws cloudformation validate-template --template-body file://template.yml >/dev/null
aws ec2 create-key-pair --key-name "$LAB" --query KeyMaterial --output text > "$KEY"
chmod 400 "$KEY"
aws cloudformation deploy --stack-name "$LAB" --template-file template.yml \
  --parameter-overrides KeyName="$LAB" MyIp="$MY_IP"
aws cloudformation describe-stacks --stack-name "$LAB" --query 'Stacks[0].Outputs' --output table
