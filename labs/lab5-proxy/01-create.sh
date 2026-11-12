#!/usr/bin/env bash
set -euo pipefail
LAB=proxy-lab
source ../common.sh

lab_net_create 80 3128   # 80 = Nginx gateway, 3128 = Squid (both open only to your IP)
lab_userdata
GW=$(lab_launch gw t3.micro); SQ=$(lab_launch squid t3.micro)
aws ec2 wait instance-status-ok --instance-ids "$GW" "$SQ"
cat >> ips.env <<IPS
GW_PUB=$(lab_ip "$GW" PublicIpAddress)
SQUID_PUB=$(lab_ip "$SQ" PublicIpAddress)
IPS
cat ips.env
