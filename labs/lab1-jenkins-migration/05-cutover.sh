#!/usr/bin/env bash
set -euo pipefail
source ./lab.env; source ./ips.env
TARGET=${1:-new}                                   # usage: ./05-cutover.sh new | old
[ "$TARGET" = new ] && IP=$NEW_PRIV || IP=$OLD_PRIV

$SSH ec2-user@$FRONT_PUB "sudo sed -i 's#proxy_pass http://.*:8080;#proxy_pass http://$IP:8080;#' /srv/nginx/default.conf
sudo docker exec front nginx -t && sudo docker exec front nginx -s reload"
curl -sI http://$FRONT_PUB/login | grep -iE 'x-jenkins|x-upstream'
