# Deployment Documentation

**Professional deployment automation for Python web applications on AWS**

---

## Quick Start

**Deploy in 15-20 minutes** → [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md)

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

---

## Documentation Structure

### 📚 Guides (How-To)

| Guide | Description | Time |
|-------|-------------|------|
| **[QUICKSTART](docs/guides/QUICKSTART.md)** | Deploy fast with automation | 15-20 min |
| **[MANUAL_DEPLOYMENT](docs/guides/MANUAL_DEPLOYMENT.md)** | Step-by-step with CLI & playbooks | 1-2 hours |
| **[OPERATIONS](docs/guides/OPERATIONS.md)** | Daily operations, updates, backups | Reference |
| **[MULTI_USER](docs/guides/MULTI_USER.md)** | Add multiple users | 10 min |
| **[SECRET_MANAGEMENT](docs/guides/SECRET_MANAGEMENT.md)** | Rotate secrets safely | 5 min |

### 📖 Reference (Technical Details)

| Reference | Description |
|-----------|-------------|
| **[ARCHITECTURE](docs/reference/ARCHITECTURE.md)** | System architecture & design decisions |
| **[PLAYBOOKS](docs/reference/PLAYBOOKS.md)** | All playbooks and their purposes |
| **[AWS_PROFILES](docs/reference/AWS_PROFILES.md)** | Manage multiple AWS accounts |
| **[SECURITY](docs/reference/SECURITY.md)** | Security hardening details |

---

## What This Does

**Creates a production-ready deployment:**

- ✅ AWS EC2 instance (Ubuntu 22.04)
- ✅ Application with Gunicorn + Nginx
- ✅ Systemd service (auto-restart)
- ✅ S3 storage for images
- ✅ IAM role (no credentials on server)
- ✅ SSL/HTTPS with Let's Encrypt (optional)
- ✅ CloudWatch monitoring (optional)
- ✅ Security hardening built-in

**Cost:** ~$10-15/month (~$2/month on AWS free tier)

---

## Prerequisites

### What You Need

```bash
# Check if you have these
aws sts get-caller-identity    # AWS CLI configured
python3 --version              # Python 3.8+
ansible --version              # Ansible 2.9+
```

**If any command fails:**
```bash
# Install deployment tools
pip3 install -r requirements.txt

# Configure AWS
aws configure
```

**Need detailed setup?** → [docs/guides/QUICKSTART.md#prerequisites](docs/guides/QUICKSTART.md#prerequisites)

---

## Configuration (Required Before Deployment)

**⚠️ You must configure variables before deploying:**

### 1. Edit Configuration File

```bash
cd deployment
vim group_vars/all.yml
```

**Required variables to change:**
- `app_name` - Your application name (technical, lowercase)
- `app_display_name` - Display name for your app
- `server_name` - Your domain or "_" for IP-only access
- `admin_email` - Your email for SSL certificates

### 2. Create Secrets Vault

```bash
# Create vault password file
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create encrypted secrets file
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

**Add your secrets:**
```yaml
---
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app.git"
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"
vault_s3_folder: "production"
vault_app_username: "admin"
vault_app_password: "strong-password-here"
```

**Detailed instructions:** → [docs/guides/QUICKSTART.md#prerequisites](docs/guides/QUICKSTART.md#prerequisites)

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
ansible-playbook -i inventories/production playbooks/setup.yml

# 3. Add SSL (optional)
ansible-playbook -i inventories/production playbooks/setup-ssl.yml

# 4. Add monitoring (optional)
ansible-playbook -i inventories/production playbooks/setup-monitoring.yml

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
ansible-playbook -i inventories/production playbooks/update.yml
```
→ [docs/guides/OPERATIONS.md#updates](docs/guides/OPERATIONS.md#updates)

### Add SSL Certificate

```bash
cd deployment
ansible-playbook -i inventories/production playbooks/setup-ssl.yml
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
| **Update** | `ansible-playbook -i inventories/production playbooks/update.yml` |
| **Logs** | `ssh ubuntu@IP` → `sudo journalctl -u myapp` |
| **Restart** | `ssh ubuntu@IP` → `sudo systemctl restart myapp` |
| **SSL** | `ansible-playbook -i inventories/production playbooks/setup-ssl.yml` |
| **Status** | `./scripts/app-deploy.sh status` |

---

## Getting Started

**Ready to deploy?**

1. **Quick:** → [docs/guides/QUICKSTART.md](docs/guides/QUICKSTART.md) (15-20 minutes)
2. **Detailed:** → [docs/guides/MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) (1-2 hours)
3. **Help:** → [docs/guides/OPERATIONS.md](docs/guides/OPERATIONS.md)

**Welcome to production!** 🎉

