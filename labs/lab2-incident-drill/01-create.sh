#!/usr/bin/env bash
set -euo pipefail
LAB=incident-drill
source ../common.sh

lab_net_create 80
lab_userdata
ID=$(lab_launch app t3.small)
aws ec2 wait instance-status-ok --instance-ids "$ID"
echo "APP_PUB=$(lab_ip "$ID" PublicIpAddress)" >> ips.env
cat ips.env
