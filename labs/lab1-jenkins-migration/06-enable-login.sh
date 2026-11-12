#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
source ./lab.env
source ./ips.env

case "${1:-}" in
  old) HOST="$OLD_PUB" ;;
  new) HOST="$NEW_PUB" ;;
  *)
    echo "Usage: $0 old|new"
    exit 1
    ;;
esac

echo "Getting Jenkins initial admin password..."

$SSH "ec2-user@$HOST" \
  "sudo cat /srv/jenkins_home/secrets/initialAdminPassword"

echo
echo "Open Jenkins:"
echo "http://$FRONT_PUB"