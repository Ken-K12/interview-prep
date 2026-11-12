#!/usr/bin/env bash
set -euo pipefail
source ./lab.env; source ./ips.env

make_job() {  # $1=name $2=cron $3=shell command
cat <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>Lab job: $1</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <triggers>
    <hudson.triggers.TimerTrigger><spec>$2</spec></hudson.triggers.TimerTrigger>
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell><command>$3</command></hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF
}

push_job() {
  make_job "$1" "$2" "$3" | $SSH ec2-user@$OLD_PUB \
    "sudo mkdir -p /srv/jenkins_home/jobs/$1 && sudo tee /srv/jenkins_home/jobs/$1/config.xml >/dev/null \
     && sudo chown -R 1000:1000 /srv/jenkins_home/jobs"
}

push_job hello-world 'H/5 * * * *' 'echo "Running on: $LAB_HOST"; java -version'
push_job disk-check  'H/5 * * * *' 'df -h /var/jenkins_home'
push_job heartbeat   '* * * * *'   'date >> "$JENKINS_HOME/heartbeat.log"; tail -3 "$JENKINS_HOME/heartbeat.log"'

$SSH ec2-user@$OLD_PUB "sudo docker restart jenkins >/dev/null
until curl -s -o /dev/null -w '%{http_code}' localhost:8080/login | grep -q 200; do sleep 5; done
curl -sg 'localhost:8080/api/json?tree=jobs[name]' | jq -r '.jobs[].name'"
