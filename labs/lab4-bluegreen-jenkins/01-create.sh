#!/usr/bin/env bash
set -euo pipefail
LAB=bluegreen-lab
source ../common.sh

# 80 = app behind Nginx, 8080 = Jenkins UI (both open only to your IP)
lab_net_create 80 8080
lab_userdata 'mkdir -p /srv/jenkins_home /srv/nginx/conf.d /srv/deploy' 'chown -R 1000:1000 /srv/jenkins_home'
ID=$(lab_launch bg t3.medium)
aws ec2 wait instance-status-ok --instance-ids "$ID"
echo "APP_PUB=$(lab_ip "$ID" PublicIpAddress)" >> ips.env
cat ips.env
