#!/usr/bin/env bash
set -euo pipefail
source ./lab.env; source ../common.sh; source ./policy.sh

aws logs create-log-group --log-group-name "$LOG_GROUP"
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 1

aws iam create-role --role-name "$ROLE" --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
set_policy full
aws iam create-instance-profile --instance-profile-name "$PROFILE" >/dev/null
aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE" --role-name "$ROLE"
sleep 15   # IAM changes need a few seconds to spread

lab_net_create
lab_userdata 'dnf install -y iptables-nft' 'mkdir -p /srv/lab-logs /srv/fb'
for try in 1 2 3 4 5; do
  ID=$(lab_launch app t3.micro --iam-instance-profile "Name=$PROFILE") && break
  echo "profile not ready, retrying..."; sleep 10
done
aws ec2 wait instance-status-ok --instance-ids "$ID"
echo "APP_PUB=$(lab_ip "$ID" PublicIpAddress)" >> ips.env
cat ips.env
