#!/usr/bin/env bash
# Starts a mock payment API: Nginx in front, a small backend behind it.
set -euo pipefail
LAB=incident-drill
source ../common.sh; source ./ips.env
lab_ready "$APP_PUB"

cat > /tmp/default.conf <<'CONF'
log_format main '$time_iso8601 $remote_addr "$request" $status $request_time';
server {
  listen 80;
  access_log /var/log/nginx/access.log main;
  location /health { return 200 "ok\n"; }
  location /pay    { proxy_connect_timeout 1s; proxy_pass http://backend:5678; }
}
CONF
lab_put "$APP_PUB" /tmp/default.conf /tmp/default.conf
lab_ssh "$APP_PUB" 'sudo mkdir -p /srv/app/conf.d /srv/app/logs && sudo mv /tmp/default.conf /srv/app/conf.d/default.conf
sudo docker network create app 2>/dev/null || true
sudo docker rm -f backend front 2>/dev/null || true
sudo docker run -d --name backend --network app --restart unless-stopped hashicorp/http-echo -text=paid
sudo docker run -d --name front --network app --restart unless-stopped -p 80:80 \
  -v /srv/app/conf.d:/etc/nginx/conf.d -v /srv/app/logs:/var/log/nginx nginx'
sleep 3
curl -s "http://$APP_PUB/pay"; curl -s "http://$APP_PUB/health"
