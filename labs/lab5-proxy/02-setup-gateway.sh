#!/usr/bin/env bash
# Nginx reverse proxy with rate limiting, in front of a small backend.
set -euo pipefail
LAB=proxy-lab
source ../common.sh; source ./ips.env
lab_ready "$GW_PUB"
lab_put "$GW_PUB" nginx-gw.conf /tmp/default.conf
lab_ssh "$GW_PUB" 'bash -s' <<'REMOTE'
set -e
sudo mkdir -p /srv/gw/conf.d /srv/gw/logs
sudo mv /tmp/default.conf /srv/gw/conf.d/default.conf
sudo docker network create gw 2>/dev/null || true
sudo docker run -d --name backend --network gw --restart unless-stopped hashicorp/http-echo -text="hello from backend"
sudo docker run -d --name nginx --network gw --restart unless-stopped -p 80:80 \
  -v /srv/gw/conf.d:/etc/nginx/conf.d:ro -v /srv/gw/logs:/var/log/nginx nginx
REMOTE
sleep 3
curl -si "http://$GW_PUB/" | grep -iE '^HTTP|x-upstream|hello'
