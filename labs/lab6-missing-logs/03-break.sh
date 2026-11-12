#!/usr/bin/env bash
# Usage: ./03-break.sh iam | path | network | fix
set -euo pipefail
source ./lab.env; source ../common.sh; source ./ips.env; source ./policy.sh
case "${1:-}" in
  iam)     set_policy no-put ;;
  path)    lab_ssh "$APP_PUB" "sudo sed -i 's#/var/log/lab/app.log#/var/log/lab/app.logs#' /srv/fb/fluent-bit.conf && sudo docker restart fb >/dev/null" ;;
  network) lab_ssh "$APP_PUB" "sudo iptables -I OUTPUT -p tcp --dport 443 -j DROP" ;;
  fix)     set_policy full
           lab_ssh "$APP_PUB" "sudo iptables -D OUTPUT -p tcp --dport 443 -j DROP 2>/dev/null || true
sudo sed -i 's#/var/log/lab/app.logs#/var/log/lab/app.log#' /srv/fb/fluent-bit.conf && sudo docker restart fb >/dev/null" ;;
  *) echo "usage: $0 iam|path|network|fix"; exit 1 ;;
esac
echo "done at $(date +%T). Wait about 30 seconds, then run ./04-diagnose.sh"
