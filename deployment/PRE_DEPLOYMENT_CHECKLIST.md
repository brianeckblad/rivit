# Pre-Deployment Checklist

**Use this before deploying** - Either automated or manual deployment.

---

## Quick Check: Are You Ready?

Run these commands. If any fail, see [Fix It](#fix-it) section:

```bash
# AWS configured?
aws sts get-caller-identity

# Tools installed?
python3 --version  # Need 3.8+
ansible --version  # Need 2.9+

# Configuration ready?
ls deployment/group_vars/all.yml
ls deployment/group_vars/production/vault.yml
```

**All working?** → You're ready! Skip to [Configuration Check](#configuration-check)

**Something failed?** → See [Fix It](#fix-it) below

---

## Fix It

### AWS CLI Not Configured

```bash
# Install AWS CLI
pip install awscli

# Configure
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Format (json)
```

**Don't have AWS keys?** → Create IAM user:
```bash
# In AWS Console:
# 1. IAM → Users → Create User
# 2. Name: {app_name}-deploy (e.g., myapp-deploy)
# 3. Attach policy: AdministratorAccess
# 4. Create Access Key → Save credentials
```

### Python/Ansible Not Installed

```bash
# macOS
brew install python3 ansible

# Ubuntu/Debian
sudo apt update
sudo apt install python3 python3-pip ansible

# Verify
python3 --version  # Should be 3.8+
ansible --version
```

### Configuration Files Missing

**1. Configure app settings:**

Edit `deployment/group_vars/all.yml`:
```yaml
app_name: your_app_name                      # Your app name (e.g., myapp, inventory_tool, etc.)
app_display_name: "Your App"                 # Display name
app_url: "https://github.com/YOUR_USERNAME/your_app_name"  # ← Change YOUR_USERNAME and app_name
```

**2. Create secrets vault:**

```bash
# Create vault password file (one-time)
echo "your-secure-password-here" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create vault
cd deployment
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

Add this content to the vault:
```yaml
---
# Git Repository
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app_name.git"  # ← Your repo

# AWS
vault_aws_region: "us-east-1"
vault_s3_bucket_name: "your-unique-bucket-name"  # ← Must be globally unique
vault_s3_folder: "production"

# App Credentials
vault_app_username: "admin"
vault_app_password: "your-secure-password"  # ← Change this

# SNS (optional)
vault_sns_topic_arn: ""

# eBay (optional - leave blank if not using)
vault_ebay_app_id: ""
vault_ebay_cert_id: ""
vault_ebay_dev_id: ""
vault_ebay_token: ""
```

---

## Configuration Check

Verify your configuration before deploying:

### 1. App Configuration

```bash
grep "app_url:" deployment/group_vars/all.yml
# Should show YOUR GitHub username, not "yourusername"
```

### 2. Vault Configuration

```bash
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# Should show YOUR repository URL
```

### 3. S3 Bucket Name

The bucket name must be **globally unique** across all AWS:

```bash
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_s3_bucket_name
# Should NOT be: your-bucket-name, your_app_name, or anything common
# Should BE: something unique like: yourname-yourapp-comics-2026
```

**Test if bucket name is available:**
```bash
aws s3 ls s3://your-chosen-bucket-name 2>&1
# Should show: "NoSuchBucket" (good - it's available!)
# If shows content: Choose a different name
```

### 4. Domain (if using SSL)

If you want SSL/custom domain:

```bash
grep "DOMAIN=" deployment/scripts/ssl-setup.sh
# Should show your actual domain, not "your-domain.com"
```

---

## AWS Setup (Required)

### Create S3 Bucket

```bash
# Replace with your unique bucket name
aws s3 mb s3://yourname-yourapp-comics-2026 --region us-east-1
```

### For Manual Deployment: Create EC2 Instance

**Only if doing manual deployment** (automated deployment creates this for you):

```bash
# Launch Ubuntu 22.04 instance
# Instance type: t3.micro (or t3.nano for cheapest)
# Security group: Allow ports 22, 80, 443
# Key pair: Create and download .pem file
```

**Automated deployment?** Skip this - the script handles it.

---

## Final Checklist

Before running deployment, verify:

### Required (Must Have)
- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] Python 3.8+ installed
- [ ] Ansible installed
- [ ] `deployment/group_vars/all.yml` configured (app_url updated)
- [ ] `deployment/group_vars/production/vault.yml` created and configured
- [ ] `~/.vault_pass` file created
- [ ] S3 bucket created in AWS
- [ ] S3 bucket name is globally unique

### For Manual Deployment Only
- [ ] EC2 instance running Ubuntu 22.04
- [ ] SSH access to EC2 instance
- [ ] Instance IP added to `deployment/inventories/production/hosts`

### For Automated Deployment Only
- [ ] IAM user has `AdministratorAccess` policy
- [ ] Ready to wait 15-20 minutes for full setup

### Optional (Can Skip)
- [ ] Domain name ready (for SSL)
- [ ] Domain updated in `deployment/scripts/ssl-setup.sh`
- [ ] eBay credentials (if using price lookup)

---

## Common Mistakes

### ❌ Using Default Bucket Name

```yaml
# DON'T:
vault_s3_bucket_name: "your_app_name"
vault_s3_bucket_name: "your-bucket-name"

# DO:
vault_s3_bucket_name: "yourname-yourapp-comics-2026"
```

### ❌ Not Updating app_url

```yaml
# DON'T:
app_url: "https://github.com/yourusername/your_app_name"

# DO:
app_url: "https://github.com/brian/your_app_name"  # Your actual username
```

### ❌ Not Updating vault_git_repo

```yaml
# DON'T:
vault_git_repo: "https://github.com/yourusername/your_app_name.git"

# DO:
vault_git_repo: "https://github.com/brian/your_app_name.git"  # Your actual repo
```

### ❌ Forgetting vault password

If you lose `~/.vault_pass`:
- You can't decrypt vault.yml
- You'll need to recreate it from scratch
- **Keep ~/.vault_pass backed up!**

---

## Verification Commands

Run these before deploying to catch issues:

```bash
# 1. AWS works
aws s3 ls
# Should list buckets (even if empty list)

# 2. S3 bucket exists
aws s3 ls s3://your-bucket-name/
# Should work (even if empty)

# 3. Vault can be read
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass
# Should show your secrets

# 4. Config has your username
grep "yourusername" deployment/group_vars/all.yml
# Should return nothing (means you updated it)

# 5. Ansible can find inventory (manual deployment only)
ansible-inventory -i deployment/inventories/production --list
# Should show your EC2 instance
```

---

## What If I Skip This?

**If you skip this checklist:**
- Deployment will fail
- You'll waste 10-15 minutes
- You'll have to debug and re-run
- Might create AWS resources you need to clean up

**5 minutes checking now = saves 30 minutes later** ✅

---

## Ready to Deploy?

### For Automated Deployment

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

→ See [README.md#quick-deploy-automated](README.md#quick-deploy-automated)

### For Manual Deployment

```bash
cd deployment
ansible-playbook -i inventories/production playbooks/setup.yml
```

→ See [README.md#manual-deploy-step-by-step](README.md#manual-deploy-step-by-step)

---

## Need Help?

- **Can't configure AWS?** → [AWS Account Setup](#aws-setup-required)
- **Don't understand vault?** → [Fix It → Configuration Files Missing](#configuration-files-missing)
- **Deployment failed?** → [README.md#troubleshooting](README.md#troubleshooting)
- **Something else?** → Check [OPERATIONS.md](OPERATIONS.md) or create GitHub issue

