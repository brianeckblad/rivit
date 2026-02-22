# Deployment Documentation

**Professional deployment automation for Python web applications on AWS**

---

## 🚀 Getting Started (The 3-Step Process)

### Step 1: Prerequisites (30 minutes)

Get your local machine ready. Do this FIRST:

→ **[PREREQUISITES.md](docs/guides/PREREQUISITES.md)**

**Sets up:**
- ✅ AWS account and IAM user
- ✅ AWS CLI on your machine
- ✅ Ansible and Python
- ✅ Deployment configuration files

**When done, you'll see:**
```bash
$ aws sts get-caller-identity
# Shows your AWS account ID
```

### Step 2: Choose Your Deployment Path

After prerequisites, pick how to deploy:

#### Option A: Fast & Automated (Recommended)
**Everything in 15-20 minutes, one command**

→ **[QUICKSTART.md](docs/guides/QUICKSTART.md)**

Best for:
- Want your app running quickly
- Trust automation (all steps documented)
- Getting started is the priority

#### Option B: Learn Step-by-Step
**Understand each component, 1-2 hours**

→ **[MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md)**

Best for:
- Want to learn how it works
- Prefer understanding before automating
- Troubleshooting existing deployments

### Step 3: After Deployment

Your app is running! What now?

| Next Step | Guide | Time |
|-----------|-------|------|
| Update your application code | [UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md) | 1-10 min |
| Add SSL/HTTPS (recommended) | [MANUAL_DEPLOYMENT.md#ssl](docs/guides/MANUAL_DEPLOYMENT.md#step-5-configure-ssl-optional) | 10 min |
| Set up monitoring & alerts | [MONITORING.md](docs/guides/MONITORING.md) | 15 min |
| Add security hardening | [SECURITY_HARDENING.md](docs/guides/SECURITY_HARDENING.md) | Reference |

---

## 📚 Complete Documentation Index

### Core Guides

| Document | Purpose | When to Use |
|----------|---------|-----------|
| [PREREQUISITES.md](docs/guides/PREREQUISITES.md) | First time setup | Before anything else |
| [QUICKSTART.md](docs/guides/QUICKSTART.md) | Automatic deployment | Want fast setup |
| [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) | Step-by-step deployment | Want to learn |

### Understanding Your Deployment

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](docs/reference/ARCHITECTURE.md) | How everything fits together |
| [INFRASTRUCTURE.md](docs/guides/INFRASTRUCTURE.md) | AWS resources explained |

### Operations & Maintenance

| Document | Purpose |
|----------|---------|
| [UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md) | Deploy code changes |
| [MONITORING.md](docs/guides/MONITORING.md) | Monitor your app (logs, alarms) |
| [OPERATIONS.md](docs/guides/OPERATIONS.md) | Backups, scaling, troubleshooting |
| [SECRET_MANAGEMENT.md](docs/guides/SECRET_MANAGEMENT.md) | Rotate passwords and credentials |
| [MULTI_USER.md](docs/guides/MULTI_USER.md) | Add more users to server |

### Optional Features

| Feature | Guide |
|---------|-------|
| SSL/HTTPS Certificate | [MANUAL_DEPLOYMENT.md#ssl](docs/guides/MANUAL_DEPLOYMENT.md#step-5-configure-ssl-optional) |
| CloudFront CDN | [CLOUDFRONT_CDN.md](docs/guides/CLOUDFRONT_CDN.md) |
| WAF (Web Firewall) | [WAF_CONFIGURATION.md](docs/guides/WAF_CONFIGURATION.md) |
| EBS Application Storage | [EBS_APPLICATION_STORAGE.md](docs/guides/EBS_APPLICATION_STORAGE.md) |
| Security Hardening | [SECURITY_HARDENING.md](docs/guides/SECURITY_HARDENING.md) |

---

## What Gets Deployed
./scripts/local-dev-setup.sh

# Or manual copy
cp group_vars/all.yml.example group_vars/all.yml
cp group_vars/vault.yml.example group_vars/vault.yml
```

**Files created:**
- `group_vars/all.yml` - Your deployment settings
- `group_vars/vault.yml` - Your secrets (encrypted)

**These are ignored by Git** - safe to commit your personal settings locally!

### Fast Deploy (If Already Configured)

```bash
cd deployment

# Option 1: Automated (everything)
ansible-playbook playbooks/provision-infrastructure.yml
ansible-playbook -i inventories playbooks/setup.yml

# Option 2: Just the app (EC2 already running)
ansible-playbook -i inventories playbooks/setup.yml
```

---

## First Time?

**Not done setup yet?** → [PREREQUISITES.md](docs/guides/PREREQUISITES.md)

**Everything ready?** Choose one:
- ⚡ Fast → [QUICKSTART.md](docs/guides/QUICKSTART.md)
- 📖 Educational → [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md)

---

## What Gets Deployed

**Complete production-ready setup:**

- ✅ AWS EC2 instance (Ubuntu 22.04)
- ✅ Application server (Gunicorn + Nginx)
- ✅ Auto-restart service (Systemd)
- ✅ Cloud storage (S3 bucket)
- ✅ Permissions (IAM role, no credentials on server)
- ✅ SSL/HTTPS (Let's Encrypt, optional)
- ✅ Monitoring (CloudWatch, optional)
- ✅ Security hardening (built-in)

**Cost:** ~$10-15/month (~$2/month on AWS free tier)

---

## Quick Facts

| Item | Value |
|------|-------|
| **Prerequisites time** | 30 minutes |
| **Automated deploy time** | 15-20 minutes |
| **Manual deploy time** | 1-2 hours |
| **Server OS** | Ubuntu 22.04 LTS |
| **App framework** | Python + Gunicorn + Nginx |
| **Process manager** | Systemd |
| **Deployment tool** | Ansible |
| **Cloud provider** | AWS |
| **Monthly cost** | ~$10-15 (free tier: ~$2) |

---

## Common Commands

```bash
# Start fresh deployment
cd deployment
./scripts/infra-complete-setup.sh

# Deploy code updates only
cd deployment
ansible-playbook -i inventories playbooks/update.yml

# View application logs
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo journalctl -u {app_name} -f

# Restart application
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo systemctl restart {app_name}
```

---

## Documentation Maintenance

**Questions or improvements?**
- **Found an error?** → Create GitHub issue with label `documentation`
- **Have a suggestion?** → Open GitHub discussion

---

**⏱️ Not started?** → Go to [PREREQUISITES.md](docs/guides/PREREQUISITES.md)  
**⏱️ Finished prerequisites?** → Choose [QUICKSTART.md](docs/guides/QUICKSTART.md) or [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md)  
**⏱️ Already deployed?** → See [UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md)

