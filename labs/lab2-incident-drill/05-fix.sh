#!/usr/bin/env bash
set -euo pipefail
LAB=incident-drill
source ../common.sh; source ./ips.env
lab_ssh "$APP_PUB" "sudo sed -i 's#backend:5679;#backend:5678;#' /srv/app/conf.d/default.conf
sudo docker start backend >/dev/null
sudo docker exec front nginx -t && sudo docker exec front nginx -s reload"
echo "fixed at $(date +%T)"
