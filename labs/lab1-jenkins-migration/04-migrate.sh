#!/usr/bin/env bash
set -euo pipefail
source ./lab.env; source ./ips.env

echo "1) Quiet down old Jenkins (no new builds)"
$SSH ec2-user@$OLD_PUB 'C=$(curl -s -c /tmp/c localhost:8080/crumbIssuer/api/json | jq -r ".crumbRequestField+\":\"+.crumb")
curl -s -b /tmp/c -H "$C" -X POST localhost:8080/quietDown -o /dev/null -w "quietDown HTTP %{http_code}\n"
until [ "$(curl -s localhost:8080/computer/api/json | jq .busyExecutors)" = 0 ]; do echo "waiting for running builds..."; sleep 5; done'

echo "2) Back up old JENKINS_HOME (for rollback)"
$SSH ec2-user@$OLD_PUB "sudo tar czf /home/ec2-user/jenkins_home_backup.tgz -C /srv jenkins_home"

echo "3) Copy JENKINS_HOME old -> new"
$SSH ec2-user@$OLD_PUB "sudo tar czf - -C /srv jenkins_home" | $SSH ec2-user@$NEW_PUB "sudo tar xzf - -C /srv"

echo "4) Start new Jenkins (newer version, Java 17)"
$SSH ec2-user@$NEW_PUB "sudo docker run -d --name jenkins --restart unless-stopped -p 8080:8080 \
  -e LAB_HOST=new -e JAVA_OPTS=-Djenkins.install.runSetupWizard=false \
  -v /srv/jenkins_home:/var/jenkins_home $NEW_IMAGE
until curl -s -o /dev/null -w '%{http_code}' localhost:8080/login | grep -q 200; do sleep 5; done
curl -sI localhost:8080/login | grep -i '^x-jenkins:'
curl -sg 'localhost:8080/api/json?tree=jobs[name,nextBuildNumber]' | jq ."
