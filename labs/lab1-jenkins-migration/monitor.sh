#!/usr/bin/env bash
source ./lab.env; source ./ips.env
while true; do
  R=$(curl -sI -m 2 http://$FRONT_PUB/login)
  CODE=$(echo "$R" | head -1 | awk '{print $2}')
  VER=$(echo "$R" | grep -i '^x-jenkins:' | tr -d '\r')
  echo "$(date +%T) ${CODE:-000} $VER"
  sleep 0.5
done
