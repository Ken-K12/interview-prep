#!/usr/bin/env bash
# Usage: ./03-break.sh backend | port
set -euo pipefail
LAB=incident-drill
source ../common.sh; source ./ips.env
case "${1:-}" in
  backend) lab_ssh "$APP_PUB" "sudo docker stop backend >/dev/null" ;;
  port)    lab_ssh "$APP_PUB" "sudo sed -i 's#backend:5678;#backend:5679;#' /srv/app/conf.d/default.conf
sudo docker exec front nginx -s reload" ;;
  *) echo "usage: $0 backend|port"; exit 1 ;;
esac
echo "broken at $(date +%T)"
