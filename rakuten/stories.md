# Rakuten DevOps (Mid) Interview Prep – Kenji Kawashima

Roles: **PSR8320** (DNS team) and **PSR8377** (Gateway/CDN/Proxy team).
All facts come from cv.txt. "[TODO: add detail]" marks details to fill in before the interview.

## Table of Contents
1. Tell me about yourself
2. Story 1 – Zero-downtime Jenkins migration
3. Story 2 – On-call for the PCI DSS payment gateway
4. Story 3 – Infrastructure as Code (CloudFormation and Ansible)
5. Story 4 – Jenkins CI/CD, release automation, Blue/Green
6. Story 5 – Proxy, gateway, and security work
7. Story 6 – Missing or delayed logs, and log collection
8. Why this role?
9. Why are you leaving consulting?
10. Honest gap answers: Kubernetes and Squid
11. Questions to ask the interviewer

---

## Tell me about yourself

I am a DevOps and cloud infrastructure engineer in Tokyo. I have more than five years of experience. Four of those years are hands-on AWS and Linux production work.

I started as a full-stack engineer at Logical Arts. I worked on an e-commerce platform on Amazon Linux and Nginx. Then I joined NRI Netcom as a DevOps and SRE engineer. I ran a PCI DSS payment gateway on AWS. It handled about 10,000 transactions per minute. I was on call, I managed Infrastructure as Code with CloudFormation and Ansible, and I kept about 100 Jenkins jobs running. I also led a zero-downtime Jenkins server migration.

After that I worked as a self-employed cloud engineer, and now I work at Avanade as a consultant. I design AWS architecture and security. I use English every day. Now I want to return to hands-on engineering and operations.

---

## Story 1 – Zero-downtime Jenkins migration from CentOS 7 to Amazon Linux 2023

**Situation:** At NRI Netcom, I worked on a global code-management platform. Our Jenkins servers ran on CentOS 7. They had to move to Amazon Linux 2023. The goal was to do this without any downtime.

**Task:** I was sub-lead of a five-member team. I led this migration. The goal was zero downtime.

**Action:** I started with a clear plan. I announced the schedule to the users in advance. Then I ran rehearsals with a parallel run. The old and new servers worked side by side. This let me find problems before the real switch. I checked the results after each rehearsal. I also supported my team members during the work. [TODO: add detail on the cutover steps and rollback plan]

**Result:** The migration finished with zero downtime. The Jenkins servers now run on Amazon Linux 2023. [TODO: add detail on number of servers or dates]

- **Fits:** both (Linux production servers; Jenkins for PSR8377, Linux migration for PSR8320)
- **Follow-up 1: How did you avoid downtime?** I used planning, user announcements, and rehearsals with a parallel run of old and new servers.
- **Follow-up 2: What was your role in the team?** I was sub-lead of a five-member team. I led the migration and reviewed and supported team members' work.
- **Keyword:** *Parallel run* – you run the old and new systems together so you can compare them and switch safely.

---

## Story 2 – On-call incident response for the PCI DSS payment gateway

**Situation:** At NRI Netcom, I operated the AWS production environment of a payment gateway for the game industry. It followed PCI DSS. It handled about 10,000 transactions per minute. Any outage affected payments.

**Task:** I was part of the on-call rotation. My job was to restore service quickly and find the root cause.

**Action:** I received alerts by phone and Slack. The alerts came from Zabbix, Datadog, and Opsgenie. I checked the logs first to find the cause. I kept the access and application logs in CloudWatch and S3, as PCI DSS requires. I also reported system status to the customer in weekly meetings.

**Result:** We had three to five production incidents per week. The average recovery time was under 30 minutes. [TODO: add detail on one specific incident and the fix]

- **Fits:** both (on-call and Linux operations; monitoring for PSR8377)
- **Follow-up 1: How do you find root causes?** I use log analysis. I trace the logs in CloudWatch to find what changed or failed.
- **Follow-up 2: Which monitoring tools did you use?** Zabbix for the payment gateway, Datadog for the POSA platform, and Opsgenie for alert notifications.
- **Keyword:** *PCI DSS* – a security standard for systems that handle card payments, including rules for access control and log retention.

---

## Story 3 – Infrastructure as Code with CloudFormation and Ansible

**Situation:** At NRI Netcom, I worked on the PCI DSS payment gateway. It ran in eight environments. Building an environment took several days. That was slow.

**Task:** I managed the Infrastructure as Code for all eight environments. My goal was to make provisioning faster. I also wanted the real resources to match the code.

**Action:** I used CloudFormation and Ansible to define the environments in code. I also helped with configuration drift detection. I used AWS Config to find differences between the IaC definitions and the real AWS resources. [TODO: add detail on Ansible roles or playbooks, and what they configured]

**Result:** Provisioning time dropped from several days to about half a day. We could also see when real resources did not match the code. This helped us keep all eight environments under control.

- **Fits:** both (Ansible is required in both roles; PSR8320 also lists Ansible/Chef)
- **Follow-up 1: What did you use Ansible for?** I used it together with CloudFormation to manage eight environments. [TODO: add detail on playbooks]
- **Follow-up 2: How did you handle drift?** I used AWS Config to detect differences between the IaC definitions and the actual AWS resources.
- **Keyword:** *Configuration drift* – when real servers or resources slowly differ from what the code says they should be.

---

## Story 4 – Jenkins CI/CD, release automation, and Blue/Green deployment

**Situation:** At NRI Netcom, I worked on the PCI DSS payment gateway and on the global POSA platform. Releases needed to run through a clear, repeatable process.

**Task:** I was responsible for the CI/CD on the payment gateway. On the POSA platform, I worked on the deployment flow.

**Action:** I built CI/CD with Jenkins and shell scripts. I maintained about 100 Jenkins jobs, including release automation. On the POSA platform, I performed Blue/Green deployments. I also improved the CodeBuild and CodeDeploy flows for ECS. I used Docker containers on ECS. [TODO: add detail on one specific pipeline]

**Result:** Releases ran through automated Jenkins jobs. This reduced manual release work. Blue/Green deployment let us switch between versions in a controlled way. I keep this habit of safe, repeatable releases. [TODO: add detail on release frequency or time saved]

- **Fits:** PSR8377 (CI/CD with Jenkins)
- **Follow-up 1: How many Jenkins jobs did you maintain?** About 100, including release automation, built with shell scripts.
- **Follow-up 2: Which deployment method did you use?** Blue/Green deployment, with CodeBuild and CodeDeploy for ECS.
- **Keyword:** *Blue/Green deployment* – you run the new version beside the old one, then move traffic over, so rollback is easy.

---

## Story 5 – Proxy, gateway, and security work

**Situation:** On the POSA platform at NRI Netcom, there was a self-managed Nginx proxy. On the payment gateway, I also had to protect a PCI DSS system with WAF and vulnerability checks.

**Task:** My task was to replace the self-managed proxy with a managed service. I also had to keep WAF rules and vulnerability management in good shape.

**Action:** I replaced the self-managed Nginx proxy with API Gateway. I tuned AWS WAF rules across six environments. I ran weekly vulnerability triage with Amazon Inspector and Vuls. I also changed Apache configurations and added subdomains. [TODO: add detail on why the Nginx proxy was replaced]

**Result:** We no longer had to manage our own Nginx proxy. WAF rules were tuned across six environments. Vulnerabilities were reviewed every week. I also reported vulnerabilities to the customer in weekly meetings. [TODO: add detail on measurable results]

- **Fits:** PSR8377 (gateway, proxy, security); partly PSR8320 (Linux middleware)
- **Follow-up 1: Have you run Squid in production?** No. I have used Nginx and Apache in production. I am learning Squid in a lab only.
- **Follow-up 2: What did you do with WAF?** I tuned AWS WAF rules across six environments.
- **Keyword:** *Reverse proxy* – a server in front of applications that receives client requests and forwards them to the right backend.

---

## Story 6 – Troubleshooting missing or delayed logs, and log collection

**Situation:** In my self-employed work, I built a security vendor's SOC modernization proof of concept on AWS. It ran two containerized services on ECS Fargate. Some logs were missing or arrived late. That made it hard to see what the system was doing.

**Task:** My task was to find why the logs were missing or late, and to fix the problem.

**Action:** I traced the problem step by step. I checked IAM permissions first. Then I checked network restrictions. Then I followed the whole data path from the source to the destination. I did not guess. I checked each point one by one. [TODO: add detail on the actual root cause]

At NRI Netcom, I also built a log collection platform with Fluent Bit.

**Result:** I traced the missing and delayed logs through IAM, network, and data paths. [TODO: add detail on what was fixed and the result]

- **Fits:** both (logging; PSR8377 lists ELK, Prometheus, Grafana, but I used CloudWatch, Datadog, Fluent Bit, and Elastic Agent)
- **Follow-up 1: What is your troubleshooting approach?** I check IAM, then the network, then the end-to-end data path.
- **Follow-up 2: Do you know ELK?** I have used Elastic Agent. [TODO: add detail on Elastic Agent use]. I have not listed ELK, Prometheus, or Grafana in production.
- **Keyword:** *Fluent Bit* – a lightweight agent that collects logs and sends them to a destination.

---

## Why this role?

**PSR8320 (DNS team):** I like Linux operations and automation. I have four years of hands-on Linux production work. I use Ansible and scripts in Bash and Python. I follow procedures and keep systems stable, as I did on a PCI DSS system. DNS is a core service, so reliability matters a lot. I want to work on it in an on-premise environment. I am ready to learn. I also know public cloud, which is a plus.

**PSR8377 (Gateway/CDN/Proxy team):** I have worked with gateways and proxies. I replaced a self-managed Nginx proxy with API Gateway. I tuned AWS WAF rules and used CloudFront. I also built Jenkins CI/CD and used Docker and Ansible. This role matches my skills well. I also want to go deeper into Kubernetes and Squid, and I am learning both.

---

## Why are you leaving consulting?

Consulting taught me a lot. I learned to design architecture, work with many teams, and explain ideas clearly. But now I mostly design and review. I miss working directly with systems.

I enjoyed my time at NRI Netcom. I was on call, I automated releases, and I fixed problems with real logs. I want to return to that. I want to build, run, and improve a service every day. Rakuten's scale is a great place to do this.

---

## Honest gap answers: Kubernetes and Squid

**Kubernetes:** "I have not run Kubernetes in production. I have only used it in lab and portfolio projects. In production, I used Docker and ECS on Fargate. I understand containers, deployments, and scaling. I am actively learning Kubernetes, and I can learn fast on the job." [TODO: add detail on your lab project]

**Squid:** "I have not run Squid in production. I have only used it in a lab. In production, I worked with Nginx, Apache, and API Gateway as proxies and gateways. I understand the proxy concepts. I am actively learning Squid." [TODO: add detail on your lab setup]

---

## Questions to ask the interviewer

1. What does a typical week look like for the team, and how is on-call organized?
2. How does the team manage change with work instructions and automation, for example with Ansible?
3. What skills do you hope a new member will build in the first six months?
