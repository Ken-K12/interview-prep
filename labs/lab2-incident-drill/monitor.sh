#!/usr/bin/env bash
# Stand-in for Zabbix/Opsgenie: sends 1 request per second and prints ALERT when /pay fails.
source ./ips.env
while true; do
  CODE=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://$APP_PUB/pay")
  if [ "$CODE" = 200 ]; then echo "$(date +%T) ok"; else echo "$(date +%T) ALERT /pay returned $CODE" | tee -a alert.log; fi
  sleep 1
done
