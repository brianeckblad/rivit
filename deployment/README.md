# Deployment

**Deploy a Python web application to AWS with Ansible**

---

## Getting Started

### Step 1: Prerequisites

Set up your local machine, AWS account, and configuration files.

→ **[PREREQUISITES.md](docs/guides/PREREQUISITES.md)** (~30 minutes)

### Step 2: Deploy

| Path | Guide | Time |
|------|-------|------|
| **Automated** (recommended) | [QUICKSTART.md](docs/guides/QUICKSTART.md) | 15-20 min |
| **Step-by-step** (learn how it works) | [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) | 1-2 hours |

### Step 3: After Deployment

| Task | Guide |
|------|-------|
| Update application code | [UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md) |
| Set up monitoring & alerts | [MONITORING.md](docs/guides/MONITORING.md) |
| Manage secrets & credentials | [SECRET_MANAGEMENT.md](docs/guides/SECRET_MANAGEMENT.md) |
| Day-to-day operations | [OPERATIONS.md](docs/guides/OPERATIONS.md) |

---

## What Gets Deployed

- ✅ AWS EC2 instance (Ubuntu 22.04) with EBS storage
- ✅ Application server (Gunicorn + Nginx)
- ✅ Auto-restart service (Systemd)
- ✅ Cloud storage (S3 bucket)
- ✅ IAM role (no credentials on server)
- ✅ Secrets in AWS Secrets Manager
- ✅ SSL/HTTPS (Let's Encrypt, optional)
- ✅ Monitoring (CloudWatch, optional)
- ✅ Security hardening (built-in)

**Cost:** ~$10-15/month (~$2/month on AWS free tier)

---

## Configuration

```bash
cd deployment

# Interactive setup (creates all.yml and vault.yml)
./scripts/local-dev-setup.sh

# Load variables into your shell
source scripts/load-vars.sh
```

---

## Documentation Index

### Core Guides

| Document | Purpose |
|----------|---------|
| [PREREQUISITES.md](docs/guides/PREREQUISITES.md) | First-time setup |
| [QUICKSTART.md](docs/guides/QUICKSTART.md) | Automated deployment |
| [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) | Step-by-step deployment |
| [UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md) | Deploy code changes |

### Operations & Maintenance

| Document | Purpose |
|----------|---------|
| [OPERATIONS.md](docs/guides/OPERATIONS.md) | Backups, scaling, troubleshooting |
| [MONITORING.md](docs/guides/MONITORING.md) | Logs, alarms, dashboards |
| [SECRET_MANAGEMENT.md](docs/guides/SECRET_MANAGEMENT.md) | Rotate passwords and credentials |
| [MULTI_USER.md](docs/guides/MULTI_USER.md) | Add users to server |

### Infrastructure & Security

| Document | Purpose |
|----------|---------|
| [INFRASTRUCTURE.md](docs/guides/INFRASTRUCTURE.md) | AWS resources explained |
| [EBS_APPLICATION_STORAGE.md](docs/guides/EBS_APPLICATION_STORAGE.md) | Application storage on EBS |
| [SECURITY_HARDENING.md](docs/guides/SECURITY_HARDENING.md) | Server hardening |
| [SECURITY.md](docs/reference/SECURITY.md) | Security model overview |

### Optional Features

| Document | Purpose |
|----------|---------|
| [CLOUDFRONT_CDN.md](docs/guides/CLOUDFRONT_CDN.md) | Content delivery network |
| [WAF_CONFIGURATION.md](docs/guides/WAF_CONFIGURATION.md) | Web application firewall |

### Reference

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](docs/reference/ARCHITECTURE.md) | System design overview |
| [APPLICATION_SECURITY.md](docs/reference/APPLICATION_SECURITY.md) | Security layers (WAF, attack detection) |
| [SECURITY.md](docs/reference/SECURITY.md) | User isolation model |
| [USER_MODEL.md](docs/reference/USER_MODEL.md) | User types and permissions |
| [GIT_CONFIGURATION.md](docs/guides/GIT_CONFIGURATION.md) | Git setup for deployment |

---

## Quick Reference

| Item | Value |
|------|-------|
| Server OS | Ubuntu 22.04 LTS |
| App server | Gunicorn + Nginx |
| Process manager | Systemd |
| Deployment tool | Ansible |
| Cloud provider | AWS |
| Region (default) | us-east-2 |
| Monthly cost | ~$10-15 (free tier: ~$2) |

---

## Common Commands

```bash
cd deployment

# Load configuration variables
source scripts/load-vars.sh

# Full infrastructure + app deployment
./scripts/infra-complete-setup.sh

# Deploy code updates only
ansible-playbook -i inventories playbooks/update.yml --vault-password-file ~/.vault_pass

# SSH to server
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@YOUR_SERVER_IP

# View logs (on server)
sudo journalctl -u ${app_name} -f

# Restart app (on server)
sudo systemctl restart ${app_name}
```
