#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")"
source ./lab.env
: "${LAB:?}" "${KEY:?}" "${OLD_IMAGE:?}" "${NEW_IMAGE:?}"
BROWSER_IP="${BROWSER_IP:-}"

# リージョン制限（KodeKloud）
case "${AWS_REGION:-}" in
  us-east-1|us-west-2|us-east-2) ;;
  *) echo "Region '${AWS_REGION:-}' not allowed (us-east-1, us-west-2, us-east-2 only)" >&2; exit 1 ;;
esac

# 実行先の確認
aws sts get-caller-identity --query '[Account,Arn]' --output text
read -rp "Deploy stack '$LAB' here? [y/N] " a; [[ $a == y ]] || exit 1

# AWSの外のチェック（CloudFormationでは確認できない）
docker manifest inspect "$OLD_IMAGE" >/dev/null
docker manifest inspect "$NEW_IMAGE" >/dev/null
[[ -e $KEY ]] && { echo "$KEY already exists" >&2; exit 1; }

MY_IP=$(curl -fsS --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]')
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
         --query 'Vpcs[0].VpcId' --output text)

aws cloudformation deploy \
  --stack-name "$LAB" \
  --template-file jenkins-lab.yaml \
  --parameter-overrides LabName="$LAB" MyIp="$MY_IP" VpcId="$VPC_ID" \
  --tags Lab="$LAB"

# Outputs → ips.env（OldPub → OLD_PUB に変換）
aws cloudformation describe-stacks --stack-name "$LAB" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output text |
  sed -E 's/([a-z])([A-Z])/\1_\2/g' | awk '{print toupper($1)"="$2}' > ips.env
[[ $(wc -l < ips.env) -eq 10 ]] || { echo "outputs missing" >&2; exit 1; }
source ./ips.env

# 秘密鍵は SSM Parameter Store から取り出す
aws ssm get-parameter --name "/ec2/keypair/$KEY_PAIR_ID" --with-decryption \
  --query Parameter.Value --output text > "$KEY"
chmod 400 "$KEY"
cat ips.env

# PC のIPが設定されていれば80番を開ける
[[ -z $BROWSER_IP ]] || ./allow-ip.sh browser "$BROWSER_IP"
