# Rampe Deployment Guide

**Deploy, operate, and maintain a Python web application on AWS.**

Start at Chapter 1 and follow the chapters in order. Chapters 8–12 are optional.

---

## Part I — Deploy

| Ch. | Guide | Time |
|-----|-------|------|
| 1 | [Prerequisites](guides/PREREQUISITES.md) | 30 min |
| 2 | [Quick Start](guides/QUICKSTART.md) — automated, recommended | 15–20 min |
| 3 | [Manual Deployment](guides/MANUAL_DEPLOYMENT.md) — step-by-step | 1–2 hrs |
| 3b | [AWS Console Deployment](guides/AWS_CONSOLE_DEPLOYMENT.md) — point-and-click via AWS web console | 1–2 hrs |

Complete Chapter 2 or 3. Your application is live.

## Part II — Operate

| Ch. | Guide |
|-----|-------|
| 4 | [Updating Your Application](guides/UPDATING_APPLICATION.md) |
| 5 | [Operations](guides/OPERATIONS.md) — backups, scaling, troubleshooting |
| 6 | [Monitoring](guides/MONITORING.md) — dashboards, alarms, alerting |
| 7 | [Secret Management](guides/SECRET_MANAGEMENT.md) |

## Part III — Harden & Extend

| Ch. | Guide |
|-----|-------|
| 8 | [Security Hardening](guides/SECURITY_HARDENING.md) |
| 9 | [Multi-User Support](guides/MULTI_USER.md) |
| 10 | [CloudFront CDN](guides/CLOUDFRONT_CDN.md) |
| 11 | [WAF Configuration](guides/WAF_CONFIGURATION.md) |
| 12 | [Git Configuration](guides/GIT_CONFIGURATION.md) |

## Part IV — Decommission

| Ch. | Guide |
|-----|-------|
| 13 | [Decommission](guides/DECOMMISSION.md) — full teardown or single-resource rollback |

---

## Reference

| Document | Topic |
|----------|-------|
| [Architecture](reference/ARCHITECTURE.md) | System design and technology choices |
| [Infrastructure](guides/INFRASTRUCTURE.md) | AWS resource details (S3, IAM, EC2, SG) |
| [EBS Storage](guides/EBS_APPLICATION_STORAGE.md) | Application storage on EBS volumes |
| [Application Security](reference/APPLICATION_SECURITY.md) | WAF rules, attack detection, rate limiting |
| [User Isolation](reference/SECURITY.md) | Two-user privilege model |
| [User Types](reference/USER_MODEL.md) | Admin vs. application user permissions |

---

## Playbook Reference

| Create | Delete | Resource |
|--------|--------|----------|
| `create-s3-bucket.yml` | `delete-s3-bucket.yml` | S3 Bucket |
| `create-iam-role.yml` | `delete-iam-role.yml` | IAM Role + Policies |
| `create-security-group.yml` | `delete-security-group.yml` | Security Group |
| `create-ssh-key.yml` | `delete-ssh-key.yml` | SSH Key Pair |
| `launch-ec2-instance.yml` | `terminate-ec2-instance.yml` | EC2 Instance |
| `setup-waf.yml` | `delete-waf.yml` | WAF Web ACL + IP set |
| `setup-cloudfront.yml` | `delete-cloudfront.yml` | CloudFront distribution (`enable_cloudfront` in vault.yml) |
| `setup-secrets-manager.yml` | `delete-secrets-manager.yml` | Secrets Manager secret |

## Common Commands

```bash
cd deployment
source scripts/load-vars.sh

# Deploy (run all three in order)
ansible-playbook playbooks/provision-infrastructure.yml --vault-password-file ~/.vault_pass
ansible-playbook playbooks/setup-server.yml --vault-password-file ~/.vault_pass
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass

# Update
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass

# Teardown
ansible-playbook playbooks/decommission.yml --vault-password-file ~/.vault_pass
```
