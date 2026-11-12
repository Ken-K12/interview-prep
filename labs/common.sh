#!/usr/bin/env bash
# Shared helpers for labs 2-6. Source this after setting LAB (a unique lab name).
set -euo pipefail
: "${LAB:?set LAB before sourcing common.sh}"
export AWS_REGION=${AWS_REGION:-ap-northeast-1}
export AWS_DEFAULT_REGION=$AWS_REGION
KEY=./$LAB.pem
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)

lab_ssh() { local h=$1; shift; ssh "${SSH_OPTS[@]}" "ec2-user@$h" "$@"; }
lab_put() { scp -q "${SSH_OPTS[@]}" "$2" "ec2-user@$1:$3"; }  # host local remote

# Key pair + security group. SSH is open only to your IP.
# Extra args are TCP ports that are also opened to your IP only.
# Instances in the same group can talk to each other on any TCP port.
lab_net_create() {
  local my_ip vpc p
  my_ip=$(curl -s https://checkip.amazonaws.com)/32
  vpc=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
  aws ec2 create-key-pair --key-name "$LAB" --query KeyMaterial --output text > "$KEY"
  chmod 400 "$KEY"
  SG=$(aws ec2 create-security-group --group-name "$LAB" --description "$LAB lab" \
       --vpc-id "$vpc" --query GroupId --output text)
  for p in 22 "$@"; do
    aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port "$p" --cidr "$my_ip" >/dev/null
  done
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 0-65535 --source-group "$SG" >/dev/null
  echo "SG=$SG" > ips.env
}

# Writes userdata.sh: installs Docker and jq. Extra args are added as lines.
lab_userdata() {
  { echo '#!/bin/bash'; echo 'dnf install -y docker jq'; echo 'systemctl enable --now docker'; printf '%s\n' "$@"; } > userdata.sh
}

# Prints the instance ID. Usage: lab_launch NAME TYPE [extra run-instances args]
lab_launch() {
  local name=$1 type=$2; shift 2
  AMI=${AMI:-$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
        --query Parameter.Value --output text)}
  aws ec2 run-instances --image-id "$AMI" --instance-type "$type" --key-name "$LAB" \
    --security-group-ids "$SG" --user-data file://userdata.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$LAB-$name},{Key=Lab,Value=$LAB}]" \
    --query 'Instances[0].InstanceId' --output text "$@"
}

# Usage: lab_ip INSTANCE_ID PublicIpAddress|PrivateIpAddress
lab_ip() { aws ec2 describe-instances --instance-ids "$1" --query "Reservations[0].Instances[0].$2" --output text; }

# Waits until SSH works and userdata.sh has finished.
lab_ready() {
  local h
  for h in "$@"; do
    until lab_ssh "$h" "cloud-init status --wait >/dev/null" 2>/dev/null; do sleep 5; done
  done
}

lab_cleanup_base() {
  local ids sg
  ids=$(aws ec2 describe-instances --filters "Name=tag:Lab,Values=$LAB" \
        Name=instance-state-name,Values=pending,running,stopped \
        --query 'Reservations[].Instances[].InstanceId' --output text)
  if [ -n "$ids" ]; then
    aws ec2 terminate-instances --instance-ids $ids >/dev/null
    aws ec2 wait instance-terminated --instance-ids $ids
  fi
  sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$LAB" \
       --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)
  if [ -n "$sg" ] && [ "$sg" != None ]; then
    aws ec2 revoke-security-group-ingress --group-id "$sg" --protocol tcp --port 0-65535 --source-group "$sg" >/dev/null 2>&1 || true
    aws ec2 delete-security-group --group-id "$sg" || true
  fi
  aws ec2 delete-key-pair --key-name "$LAB" || true
  rm -f "$KEY" ips.env userdata.sh
}
