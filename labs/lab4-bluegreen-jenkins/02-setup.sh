#!/usr/bin/env bash
# Builds Jenkins (with Docker CLI), makes the first deployment, and starts Jenkins.
set -euo pipefail
LAB=bluegreen-lab
source ../common.sh; source ./ips.env
lab_ready "$APP_PUB"

lab_put "$APP_PUB" Dockerfile /tmp/Dockerfile
lab_put "$APP_PUB" bluegreen.sh /tmp/bluegreen.sh
lab_ssh "$APP_PUB" 'bash -s' <<'REMOTE'
set -e
sudo install -m 755 /tmp/bluegreen.sh /srv/deploy/bluegreen.sh
sudo docker build -t lab-jenkins -f /tmp/Dockerfile /tmp
sudo /srv/deploy/bluegreen.sh deploy v0
sudo chown -R 1000:1000 /srv/nginx
sudo docker run -d --name jenkins --network bg --restart unless-stopped -p 8080:8080 \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -e JAVA_OPTS=-Djenkins.install.runSetupWizard=false \
  -v /srv/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock \
  -v /srv/nginx:/srv/nginx -v /srv/deploy:/deploy:ro lab-jenkins
until curl -s -o /dev/null -w '%{http_code}' localhost:8080/login | grep -q 200; do sleep 5; done
echo "Jenkins ready"
REMOTE
curl -si "http://$APP_PUB/" | grep -iE '^HTTP|x-color|blue'
