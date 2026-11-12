#!/bin/sh
while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO request id=$RANDOM" >> /logs/app.log
  sleep 2
done
