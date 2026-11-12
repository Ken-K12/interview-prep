#!/usr/bin/env bash
set -euo pipefail
source ./lab.env
IDS=$(aws ec2 describe-instances --filters Name=tag:Lab,Values=$LAB \
      Name=instance-state-name,Values=pending,running,stopped \
      --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then aws ec2 terminate-instances --instance-ids $IDS >/dev/null; aws ec2 wait instance-terminated --instance-ids $IDS; fi
aws ec2 delete-security-group --group-name "$LAB"
aws ec2 delete-key-pair --key-name "$LAB"
rm -f "$KEY" ips.env userdata.sh
echo "cleanup done"
