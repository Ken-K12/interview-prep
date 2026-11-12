#!/usr/bin/env bash
# Run in a second terminal. Shows status code, live color, and body twice per second.
source ./ips.env
while true; do
  rm -f /tmp/h
  BODY=$(curl -s -m 2 -D /tmp/h "http://$APP_PUB/")
  CODE=$(awk 'NR==1{print $2}' /tmp/h 2>/dev/null)
  COLOR=$(grep -i '^x-color' /tmp/h 2>/dev/null | tr -d '\r')
  echo "$(date +%T) ${CODE:-000} $COLOR $BODY"
  sleep 0.5
done
