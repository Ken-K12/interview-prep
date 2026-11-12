#!/usr/bin/env bash
set -euo pipefail
source ./lab.env; source ./ips.env

for h in $OLD_PUB $NEW_PUB $FRONT_PUB; do $SSH ec2-user@$h "cloud-init status --wait >/dev/null"; done

$SSH ec2-user@$OLD_PUB "sudo docker run -d --name jenkins --restart unless-stopped -p 8080:8080 \
  -e LAB_HOST=old -e JAVA_OPTS=-Djenkins.install.runSetupWizard=false \
  -v /srv/jenkins_home:/var/jenkins_home $OLD_IMAGE
until curl -s -o /dev/null -w '%{http_code}' localhost:8080/login | grep -q 200; do sleep 5; done
echo 'old Jenkins: ready'"

$SSH ec2-user@$FRONT_PUB "sudo mkdir -p /srv/nginx && sudo tee /srv/nginx/default.conf >/dev/null" <<EOF
server {
  listen 80;
  location / {
    proxy_pass http://$OLD_PRIV:8080;
    proxy_set_header Host \$http_host;
    add_header X-Upstream \$upstream_addr always;
  }
}
EOF
$SSH ec2-user@$FRONT_PUB "sudo docker run -d --name front --restart unless-stopped -p 80:80 \
  -v /srv/nginx:/etc/nginx/conf.d:ro nginx"
curl -sI http://$FRONT_PUB/login | grep -iE '^HTTP|x-jenkins|x-upstream'
