#!/usr/bin/env bash
# Usage: ./allow-ip.sh browser <PC_IP> | ./allow-ip.sh codespace
set -Eeuo pipefail
cd "$(dirname "$0")"
source ./lab.env
source ./ips.env
: "${SG:?}" "${FRONT_PUB:?}"

MODE="${1:-}"
IP_RE='^((25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})$'
CS_IP=$(curl -fsS --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]')

case "$MODE" in
  browser)
    IP="${2:-}"
    [[ $IP =~ $IP_RE ]] || { echo "Usage: $0 browser <PC_IPv4>" >&2; exit 1; }
    if [[ $IP == "$CS_IP" ]]; then
      echo "$IP is the Codespace egress IP, not your PC IP." >&2
      echo "On your PC run in PowerShell:" >&2
      echo '  (Invoke-RestMethod https://checkip.amazonaws.com).Trim() | Set-Clipboard' >&2
      exit 1
    fi
    PORTS=(80) ;;
  codespace)
    IP="$CS_IP"
    [[ $IP =~ $IP_RE ]] || { echo "Could not detect Codespace IP: '$IP'" >&2; exit 1; }
    PORTS=(22 80) ;;
  *) echo "Usage: $0 browser <PC_IP> | $0 codespace" >&2; exit 1 ;;
esac

DESC="lab:$MODE"
CIDR="$IP/32"

for PORT in "${PORTS[@]}"; do
  # Revoke rules with the same Description but a different CIDR
  OLD=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG" \
    --query "SecurityGroupRules[?!IsEgress && FromPort==\`$PORT\` && ToPort==\`$PORT\` && Description=='$DESC' && CidrIpv4!='$CIDR'].CidrIpv4" \
    --output text)
  for C in $OLD; do
    aws ec2 revoke-security-group-ingress --group-id "$SG" --ip-permissions \
      "IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges=[{CidrIp=$C}]" >/dev/null
    echo "Revoked $C on tcp $PORT ($DESC)"
  done

  # Add the rule; a duplicate error means it already exists (idempotent)
  if ERR=$(aws ec2 authorize-security-group-ingress --group-id "$SG" --ip-permissions \
      "IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges=[{CidrIp=$CIDR,Description=$DESC}]" 2>&1); then
    echo "Added $CIDR on tcp $PORT ($DESC)"
  elif [[ $ERR == *InvalidPermission.Duplicate* ]]; then
    # Same CIDR exists (maybe with another Description): refresh the Description
    aws ec2 update-security-group-rule-descriptions-ingress --group-id "$SG" --ip-permissions \
      "IpProtocol=tcp,FromPort=$PORT,ToPort=$PORT,IpRanges=[{CidrIp=$CIDR,Description=$DESC}]" >/dev/null
    echo "Already allowed $CIDR on tcp $PORT ($DESC)"
  else
    echo "$ERR" >&2; exit 1
  fi
done

# Save BROWSER_IP to lab.env (update or append)
if [[ $MODE == browser ]]; then
  if grep -q '^export BROWSER_IP=' lab.env; then
    sed -i "s|^export BROWSER_IP=.*|export BROWSER_IP=\"$IP\"|" lab.env
  else
    echo "export BROWSER_IP=\"$IP\"" >> lab.env
  fi
fi

echo "--- Port 22/80 rules ---"
# shellcheck disable=SC2016  # backticks are JMESPath literals, not shell
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$SG" \
  --query 'SecurityGroupRules[?!IsEgress && (FromPort==`22` || FromPort==`80`)].[FromPort,CidrIpv4,Description]' \
  --output text
echo "Open: http://$FRONT_PUB"
