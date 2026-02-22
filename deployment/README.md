# Deployment Documentation

**Professional deployment automation for Python web applications on AWS**

---

## 🚀 Getting Started

### New to this deployment? Start here:

1. **[PREREQUISITES.md](docs/guides/PREREQUISITES.md)** (30 min)
   - AWS account setup
   - AWS CLI configuration
   - Local tools installation
   - Configuration files

2. **Then choose your deployment method:**
   - **Fast?** → [QUICKSTART.md](docs/guides/QUICKSTART.md) (15-20 min)
   - **Learn?** → [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) (1-2 hours)

---

## 📚 Documentation Guide

### Start Here

| Document | Purpose | Time |
|----------|---------|------|
| **[PREREQUISITES.md](docs/guides/PREREQUISITES.md)** | Setup AWS account, CLI, tools | 30 min |
| **[ANSIBLE_INVENTORY_SETUP.md](docs/guides/ANSIBLE_INVENTORY_SETUP.md)** | Configure server location (hosts.yml) | 5 min |

**Application Configuration:**
| Document | Purpose | Time |
|----------|---------|------|
| **[APP_CONFIGURATION_GUIDE.md](../APP_CONFIGURATION_GUIDE.md)** | Configure Flask application (.env) | 10 min |

### Deployment Methods

| Guide | Best For | Time |
|-------|----------|------|
| **[QUICKSTART.md](docs/guides/QUICKSTART.md)** | Fast deployment with automation | 15-20 min |
| **[MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md)** | Learn by doing, step-by-step | 1-2 hours |
| **[INFRASTRUCTURE.md](docs/guides/INFRASTRUCTURE.md)** | Just AWS resources (no app) | 15 min |

### After Deployment

| Guide | Purpose | Time |
|-------|---------|------|
| **[UPDATING_APPLICATION.md](docs/guides/UPDATING_APPLICATION.md)** | Deploy code changes and updates | 1-10 min |
| **[SECURITY_HARDENING.md](docs/guides/SECURITY_HARDENING.md)** | Verify hardening is applied | Reference |
| **[WAF_CONFIGURATION.md](docs/guides/WAF_CONFIGURATION.md)** | Set up Web Application Firewall | 10 min |
| **[CLOUDFRONT_CDN.md](docs/guides/CLOUDFRONT_CDN.md)** | Speed up with global CDN | 5 min |

### Operations & Maintenance

| Guide | Purpose |
|-------|---------|
| **[MONITORING.md](docs/guides/MONITORING.md)** | Create dashboards and alarms |
| **[OPERATIONS.md](docs/guides/OPERATIONS.md)** | Updates, backups, scaling |
| **[MULTI_USER.md](docs/guides/MULTI_USER.md)** | Add additional users |
| **[SECRET_MANAGEMENT.md](docs/guides/SECRET_MANAGEMENT.md)** | Rotate secrets safely |

### Reference & Architecture

| Reference | Purpose |
|-----------|---------|
| **[ARCHITECTURE.md](docs/reference/ARCHITECTURE.md)** | System design & decisions |
| **[PLAYBOOKS.md](docs/reference/PLAYBOOKS.md)** | All playbooks documented |
| **[AWS_PROFILES.md](docs/reference/AWS_PROFILES.md)** | Multiple AWS accounts |
| **[SECURITY.md](docs/reference/SECURITY.md)** | Security hardening details |

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

## Quick Reference

### Configuration Files

Your personal settings are **NOT** committed to Git (for security):

```bash
cd deployment

# Create your config files from templates
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

## Documentation Maintenance

**Help keep documentation accurate and up-to-date:**

### For Users
- **Have feedback?** → [FEEDBACK_FORM.md](../FEEDBACK_FORM.md)
- **Found an error?** → Create GitHub issue with label `documentation`
- **Have a suggestion?** → Open GitHub discussion in #documentation

### For Maintainers
- **Quarterly review?** → [MAINTENANCE_CHECKLIST.md](docs/MAINTENANCE_CHECKLIST.md)
- **Need to update docs?** → [SYNC_GUIDE.md](docs/SYNC_GUIDE.md)
- **Want to validate?** → `bash docs/validate-docs.sh`
- **Track changes?** → [CHANGELOG.md](docs/CHANGELOG.md)

### Documentation Quality
- ✅ All 21 playbooks documented
- ✅ Complete prerequisites guide
- ✅ Multiple deployment options
- ✅ Step-by-step procedures
- ✅ Troubleshooting guides
- ✅ Best practices
- ✅ Cost/time estimates

**Standard pattern used by npm, docker, and most tools.**

---

**⚠️ You must configure variables before deploying:**

### 1. Edit Configuration File

```bash
cd deployment

# Create your config from template
cp group_vars/all.yml.example group_vars/all.yml
nano group_vars/all.yml
```

**Required variables to change:**
- `app_name` - Your application name (technical, lowercase)
- `app_display_name` - Display name for your app
- `server_name` - Your domain or "_" for IP-only access
- `ssl_email` - Your email for SSL certificate notifications (only if using SSL)

### 2. Create Secrets Vault

```bash
# Create vault password file (master password for encryption)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create secrets file from template
cp group_vars/vault.yml.example group_vars/vault.yml

# Edit with your secrets
nano group_vars/vault.yml
```

**Add your secrets:**
```yaml
---
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app.git"
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"
vault_s3_folder: "data"
vault_app_username: "admin"
vault_app_password: "strong-password-here"
```

**⚠️ THEN ENCRYPT THE VAULT:**

```bash
cd deployment

# Encrypt vault.yml (REQUIRED - do this before deploying!)
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass

# Verify it's encrypted
head -1 group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

**Or use the setup script:**
```bash
./scripts/local-dev-setup.sh  # Creates and encrypts all files automatically
```

**Detailed instructions:** → [docs/guides/PREREQUISITES.md](docs/guides/PREREQUISITES.md)

---

## Deployment Options

### Option 1: Automated (Recommended)

**One command does everything:**

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

**What it does:**
1. Creates S3 bucket
2. Provisions EC2 instance
3. Deploys application
4. Optional: SSL setup
5. Optional: Monitoring

**Duration:** 15-20 minutes  
**Guide:** [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md)

### Option 2: Step-by-Step

**Individual playbooks for each component:**

```bash
cd deployment

# 1. Provision infrastructure (orchestration)
ansible-playbook playbooks/provision-infrastructure.yml

# OR run individual components:
ansible-playbook playbooks/create-s3-bucket.yml
ansible-playbook playbooks/create-iam-role.yml
ansible-playbook playbooks/create-security-group.yml
ansible-playbook playbooks/create-ssh-key.yml
ansible-playbook playbooks/launch-ec2-instance.yml

# 2. Deploy application
ansible-playbook -i inventories playbooks/setup.yml

# 3. Add SSL (optional)
ansible-playbook -i inventories playbooks/setup-ssl.yml

# 4. Add monitoring (optional)
ansible-playbook -i inventories playbooks/setup-monitoring.yml

# 5. Add CloudFront CDN (optional)
ansible-playbook playbooks/setup-cloudfront.yml

# 6. Add WAF protection (optional)
ansible-playbook playbooks/setup-waf.yml

# 7. Setup Secrets Manager (optional)
ansible-playbook playbooks/setup-secrets-manager.yml
```

**Duration:** 30-40 minutes  
**Guide:** [docs/guides/MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md)

**Each playbook = one AWS component**
- Validate after each step
- Skip optional components
- Debug easily if something fails

### Option 3: Manual AWS CLI

**Full control with AWS CLI commands:**

Each step has both playbook AND manual CLI options.

**Guide:** [docs/guides/MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) (Option B for each step)

---

## Common Tasks

### First Time Deployment

```bash
cd deployment
./scripts/infra-complete-setup.sh
```
→ [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md)

### Update Application

```bash
cd deployment
ansible-playbook -i inventories playbooks/update.yml
```
→ [docs/guides/OPERATIONS.md#updates](docs/guides/OPERATIONS.md#updates)

### Add SSL Certificate

```bash
cd deployment
ansible-playbook -i inventories playbooks/setup-ssl.yml
```
→ [docs/guides/MANUAL_DEPLOYMENT.md#step-3-configure-ssl-optional](docs/guides/MANUAL_DEPLOYMENT.md#step-3-configure-ssl-optional)

### Rotate Secret

```bash
cd deployment
ansible-playbook playbooks/secret-rotate.yml -e secret_key=YOUR_KEY
ansible-playbook playbooks/secret-promote.yml -e secret_key=YOUR_KEY
```
→ [docs/guides/SECRET_MANAGEMENT.md](docs/guides/SECRET_MANAGEMENT.md)

### View Logs

```bash
ssh ubuntu@YOUR_SERVER_IP
sudo journalctl -u myapp -n 50
```
→ [docs/guides/OPERATIONS.md#logs](docs/guides/OPERATIONS.md#logs)

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| **Cloud** | AWS (EC2, S3, IAM, CloudWatch) |
| **OS** | Ubuntu 22.04 LTS |
| **Python** | Python 3.10 |
| **Web Server** | Nginx |
| **App Server** | Gunicorn (4 workers) |
| **Process Manager** | Systemd |
| **Deployment** | Ansible 2.9+ |
| **SSL** | Let's Encrypt (certbot) |
| **Secrets** | AWS Secrets Manager + Ansible Vault |
| **Monitoring** | AWS CloudWatch |

---

## Quick Reference

| Task | Command |
|------|---------|
| **Deploy** | `./scripts/infra-complete-setup.sh` |
| **Update** | `ansible-playbook -i inventories playbooks/update.yml` |
| **Logs** | `ssh ubuntu@IP` → `sudo journalctl -u myapp` |
| **Restart** | `ssh ubuntu@IP` → `sudo systemctl restart myapp` |
| **SSL** | `ansible-playbook -i inventories playbooks/setup-ssl.yml` |
| **Status** | `./scripts/app-deploy.sh status` |

---

## Getting Started

**Ready to deploy?**

1. **Quick:** → [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) (15-20 minutes)
2. **Detailed:** → [docs/guides/MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) (1-2 hours)
3. **Help:** → [docs/guides/OPERATIONS.md](docs/guides/OPERATIONS.md)

**Your application is deployed!** 🎉

