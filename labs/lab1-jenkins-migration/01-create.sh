#!/usr/bin/env bash
set -Eeuo pipefail          # -E: ERR trap を関数内にも引き継ぐ
umask 077                   # 作成するファイルを本人だけが読めるようにする（鍵・env）
cd "$(dirname "$0")"
source ./lab.env

die() { echo "ERROR: $*" >&2; exit 1; }

# --- 1. 必須変数のチェック ---
: "${LAB:?LAB is not set}" "${KEY:?KEY is not set}"
: "${OLD_IMAGE:?OLD_IMAGE is not set}" "${NEW_IMAGE:?NEW_IMAGE is not set}"
BROWSER_IP="${BROWSER_IP:-}"
IPV4_RE='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

# --- 2. 実行先の確認 ---
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-$(aws configure get region || true)}
echo "Account=$ACCOUNT  Region=$REGION  Lab=$LAB"
read -rp "Create resources here? [y/N] " ans
[[ $ans == y ]] || die "aborted"

# --- 3. 事前チェック（ここではまだ何も作らない） ---
docker manifest inspect "$OLD_IMAGE" >/dev/null || die "image not found: $OLD_IMAGE"
docker manifest inspect "$NEW_IMAGE" >/dev/null || die "image not found: $NEW_IMAGE"

MY_IP=$(curl -fsS --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]')
[[ $MY_IP =~ $IPV4_RE ]] || die "invalid MY_IP: '$MY_IP'"
[[ -z $BROWSER_IP || $BROWSER_IP =~ $IPV4_RE ]] || die "invalid BROWSER_IP: '$BROWSER_IP'"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
         --query 'Vpcs[0].VpcId' --output text)
[[ $VPC_ID == vpc-* ]] || die "default VPC not found"

AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
      --query Parameter.Value --output text)
[[ $AMI == ami-* ]] || die "AMI not found"

[[ -e $KEY ]] && die "$KEY already exists"
aws ec2 describe-key-pairs --key-names "$LAB" >/dev/null 2>&1 && die "key pair '$LAB' already exists"

# --- 4. 失敗したらロールバック ---
IDS=(); SG=""; KEY_CREATED=""
rollback() {
  echo "ERROR at line $1. Rolling back..." >&2
  if ((${#IDS[@]})); then
    aws ec2 terminate-instances --instance-ids "${IDS[@]}" >/dev/null || true
    aws ec2 wait instance-terminated --instance-ids "${IDS[@]}" || true
  fi
  [[ -n $SG ]] && { aws ec2 delete-security-group --group-id "$SG" || true; }
  [[ -n $KEY_CREATED ]] && { aws ec2 delete-key-pair --key-name "$LAB" || true; rm -f "$KEY"; }
}
trap 'rollback $LINENO' ERR

# --- 5. キーペア ---
aws ec2 create-key-pair --key-name "$LAB" --key-type ed25519 \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Lab,Value=$LAB}]" \
  --query KeyMaterial --output text > "$KEY"
KEY_CREATED=1
chmod 400 "$KEY"

# --- 6. セキュリティグループ ---
SG=$(aws ec2 create-security-group --group-name "$LAB" --description "Jenkins migration lab" \
     --vpc-id "$VPC_ID" \
     --tag-specifications "ResourceType=security-group,Tags=[{Key=Lab,Value=$LAB}]" \
     --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22   --cidr "$MY_IP/32"
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80   --cidr "$MY_IP/32"
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 8080 --source-group "$SG"
if [[ -n $BROWSER_IP && $BROWSER_IP != "$MY_IP" ]]; then
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr "$BROWSER_IP/32"
fi

# --- 7. user data ---
cat > userdata.sh <<'EOF'
#!/bin/bash
set -euxo pipefail
exec > /var/log/userdata.log 2>&1
dnf install -y docker jq
systemctl enable --now docker
mkdir -p /srv/jenkins_home && chown 1000:1000 /srv/jenkins_home
EOF

# --- 8. EC2 ---
launch() {  # $1=name $2=instance type
  aws ec2 run-instances --image-id "$AMI" --instance-type "$2" --key-name "$LAB" \
    --security-group-ids "$SG" --user-data file://userdata.sh \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"Encrypted":true,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications \
      "ResourceType=instance,Tags=[{Key=Name,Value=$LAB-$1},{Key=Lab,Value=$LAB}]" \
      "ResourceType=volume,Tags=[{Key=Lab,Value=$LAB}]" \
    --query 'Instances[0].InstanceId' --output text
}
OLD=$(launch old t3.medium);   IDS+=("$OLD")    # $( ) はサブシェルなので、IDS への追加は外で行う
NEW=$(launch new t3.medium);   IDS+=("$NEW")
FRONT=$(launch front t3.micro); IDS+=("$FRONT")

echo "Waiting for instances..."
aws ec2 wait instance-status-ok --instance-ids "${IDS[@]}"

# --- 9. IP を取得してチェックしてから書き出す ---
q() { aws ec2 describe-instances --instance-ids "$1" \
        --query "Reservations[0].Instances[0].$2" --output text; }
OLD_PUB=$(q "$OLD" PublicIpAddress);   OLD_PRIV=$(q "$OLD" PrivateIpAddress)
NEW_PUB=$(q "$NEW" PublicIpAddress);   NEW_PRIV=$(q "$NEW" PrivateIpAddress)
FRONT_PUB=$(q "$FRONT" PublicIpAddress)
for v in OLD_PUB OLD_PRIV NEW_PUB NEW_PRIV FRONT_PUB; do
  [[ ${!v} =~ $IPV4_RE ]] || die "$v is invalid: '${!v}'"   # ${!v} = 変数名 v が指す変数の値
done

cat > ips.env <<EOF
SG=$SG
OLD_ID=$OLD
NEW_ID=$NEW
FRONT_ID=$FRONT
OLD_PUB=$OLD_PUB
OLD_PRIV=$OLD_PRIV
NEW_PUB=$NEW_PUB
NEW_PRIV=$NEW_PRIV
FRONT_PUB=$FRONT_PUB
EOF

trap - ERR      # 成功したので、ロールバックを解除する
cat ips.env
