#!/usr/bin/env bash
# Jenkins jobs are config.xml files. These freestyle jobs call the shell script, as in a script-based CI/CD flow.
set -euo pipefail
LAB=bluegreen-lab
source ../common.sh; source ./ips.env

make_job() {  # $1=name $2=shell command
cat <<XML
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>Lab job: $1</description>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <builders><hudson.tasks.Shell><command>$2</command></hudson.tasks.Shell></builders>
</project>
XML
}
push_job() {
  make_job "$1" "$2" | lab_ssh "$APP_PUB" "sudo mkdir -p /srv/jenkins_home/jobs/$1 && sudo tee /srv/jenkins_home/jobs/$1/config.xml >/dev/null \
    && sudo chown -R 1000:1000 /srv/jenkins_home/jobs"
}
push_job bg-deploy        '/deploy/bluegreen.sh deploy "build-$BUILD_NUMBER"'
push_job bg-deploy-broken '/deploy/bluegreen.sh deploy "build-$BUILD_NUMBER" --broken'
push_job bg-rollback      '/deploy/bluegreen.sh rollback'
lab_ssh "$APP_PUB" "sudo docker restart jenkins >/dev/null
until curl -s -o /dev/null -w '%{http_code}' localhost:8080/login | grep -q 200; do sleep 5; done
curl -sg 'localhost:8080/api/json?tree=jobs[name]' | jq -r '.jobs[].name'"
