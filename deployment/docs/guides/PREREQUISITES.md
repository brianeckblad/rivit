# Prerequisites Guide

**Everything you need to set up before deploying {app_name}**

---

## Table of Contents

1. [AWS Account Setup](#aws-account-setup)
2. [AWS CLI Configuration](#aws-cli-configuration)
3. [Local Tools Installation](#local-tools-installation)
4. [Deployment Configuration](#deployment-configuration)
5. [Verification Checklist](#verification-checklist)

---

## AWS Account Setup

**If you already have an AWS account and IAM user, skip to [AWS CLI Configuration](#aws-cli-configuration)**

### Step 1: Create AWS Account

1. Go to [AWS Console](https://aws.amazon.com)
2. Click **Create an AWS Account**
3. Follow the setup wizard:
   - Email address (use your personal email, not work)
   - Password (strong password, save it)
   - Account name (e.g., "my-apps" or "personal-projects")
   - Business/Personal (choose based on use case)
4. Add payment method (credit card required, AWS free tier available)
5. Verify identity (phone call or SMS)
6. Complete sign-up

**Your AWS Account ID:** Found in [AWS Console → Account](https://console.aws.amazon.com/billing/home#/account)
- Write it down: `123456789012`

**⚠️ Important:** Your root account has full access. **Never use it for daily work.** Create an IAM user instead.

### Step 2: Create IAM User

**Why:** Root account should only be used for account setup. Create a limited IAM user for deployment.

1. Go to [IAM Console](https://console.aws.amazon.com/iam/home#/users)
2. Click **Create User**
3. User name: `{app_name}-deployer`
4. Check **Access key - Programmatic access**
5. Click **Next: Permissions**
6. Click **Attach existing policies directly**
7. Search and attach:
   - `AmazonEC2FullAccess` - Create/manage EC2 instances
   - `AmazonS3FullAccess` - Create/manage S3 buckets
   - `IAMFullAccess` - Create/manage IAM roles
   - `SecretsManagerReadWrite` - Manage secrets
   - `CloudWatchLogsFullAccess` - View logs and metrics
8. Click **Next: Tags** (skip)
9. Click **Create user**

### Step 3: Save Access Keys

**IMPORTANT:** Download and save these immediately. You won't see them again.

1. After creating user, you'll see **Access key ID** and **Secret access key**
2. Click **Download .csv** - Save this file securely
3. Store in a safe place (password manager, secure location)

**Example (fake credentials):**
```
Access key ID: AKIAIOSFODNN7EXAMPLE
Secret access key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

⚠️ **NEVER commit these to Git or share them!**

---

## AWS CLI Configuration

**Install AWS CLI and set up your credentials**

### Step 1: Install AWS CLI

**macOS:**
```bash
# Using Homebrew (recommended)
brew install awscli

# Or download from AWS
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Verify
aws --version
# Should show: aws-cli/2.x.x
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install -y awscli

# Verify
aws --version
```

**Windows:**
- Download and run [AWS CLI MSI installer](https://awscli.amazonaws.com/AWSCLIV2.msi)

### Step 2: Configure AWS CLI Profile

**For Single Account (Easiest):**

```bash
# Interactive configuration
aws configure

# Follow prompts:
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-2
Default output format [None]: json
```

**For Multiple Accounts (Recommended):**

Use named profiles to manage multiple AWS accounts without reconfiguring.

```bash
# Configure first account
aws configure --profile {app_name}-production
# Enter credentials and region

# Configure second account
aws configure --profile {app_name}-staging
# Enter credentials and different region

# Use with commands
aws s3 ls --profile {app_name}-production
aws ec2 describe-instances --profile {app_name}-staging
```

**⚠️ Don't know which approach?** → Start with single account (profile `default`). You can add more profiles later.

**For detailed setup:** → [AWS_PROFILES.md](../reference/AWS_PROFILES.md)

### Step 3: Verify Configuration

```bash
# Test your credentials work
aws sts get-caller-identity

# Should output:
{
    "UserId": "AIDAJ45Q7YFFAREXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/{app_name}-deployer"
}

# If using a named profile
aws sts get-caller-identity --profile {app_name}-production
```

**Problem?**
- ❌ "Unable to locate credentials" → Run `aws configure` again
- ❌ "InvalidUserID" → Check your Access Key ID is correct
- ❌ "SignatureDoesNotMatch" → Check your Secret Access Key is correct

---

## Local Tools Installation

**Install deployment tools on your local machine**

### What You Need

| Tool | Purpose | Min Version |
|------|---------|------------|
| **Python** | Runtime for deployment | 3.8+ |
| **Ansible** | Automation tool | 2.9+ |
| **Git** | Version control | Latest |
| **SSH** | Secure shell (usually pre-installed) | Latest |

### Step 1: Check What You Have

```bash
# Check Python
python3 --version
# Should show: Python 3.8 or higher

# Check Ansible
ansible --version
# Should show: Ansible 2.9 or higher

# Check Git
git --version
# Should show: Git 2.x or higher

# Check SSH
ssh -V
# Should show: OpenSSH version
```

### Step 2: Install Missing Tools

**macOS:**
```bash
# Using Homebrew
brew install python3 ansible git openssh

# Or install Ansible via pip
pip3 install ansible
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install -y python3 python3-pip git openssh-client

# Install Ansible
sudo apt install -y ansible
# Or via pip
pip3 install ansible
```

**Windows:**
- Install [Git Bash](https://gitforwindows.org/)
- Install [Python 3](https://www.python.org/downloads/)
- Install [Ansible on Windows](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-windows)

### Step 3: Install Deployment Requirements

```bash
# Navigate to deployment directory
cd /path/to/{app_name}/deployment

# Install Python requirements (Ansible plugins, AWS SDK, etc.)
pip3 install -r requirements.txt

# Verify Ansible
ansible --version

# Verify Ansible can run playbooks
ansible-playbook --version
```

---

## Deployment Configuration

**Create your personal deployment settings (not tracked in Git)**

### Step 1: Use Configuration Templates

```bash
cd deployment

# Option A: Automatic setup (recommended)
./scripts/local-dev-setup.sh

# Option B: Manual copy
cp group_vars/all.yml.example group_vars/all.yml
cp group_vars/vault.yml.example group_vars/vault.yml
```

**This creates:**
- `group_vars/all.yml` - Your application settings (ignored by Git)
- `group_vars/vault.yml` - Your secrets (ignored by Git)

**Why?** Your configuration contains sensitive data and personal choices. It should **never** be committed to Git.

### Step 2: Edit Application Configuration

```bash
cd deployment
nano group_vars/all.yml
```

**Required variables at top of file:**

```yaml
################################
# APPLICATION CONFIGURATION
################################
app_name: myapp                          # CHANGE THIS - technical name, lowercase
app_display_name: "My App"              # CHANGE THIS - friendly display name
app_username: appuser                   # Application user account name

################################
# AWS CONFIGURATION
################################
aws_region: us-east-2                   # CHANGE THIS - region for your resources
s3_bucket_name: "yourname-myapp-2026"   # CHANGE THIS - must be globally unique
s3_folder: data                         # Folder within bucket for app data

################################
# DOMAIN & SSL
################################
server_name: "_"                        # "_" for IP access only, or "your-domain.com"
ssl_email: "you@example.com"            # Email for SSL certificate notifications

################################
# INSTANCE CONFIGURATION
################################
instance_type: t3.micro                 # AWS free tier eligible
instance_name: "{app_name}-server"      # Name shown in AWS Console
ubuntu_version: 22.04                   # Ubuntu LTS version

################################
# ADMIN USER
################################
admin_username: ubuntu                  # Default SSH user for Ubuntu AMI
admin_email: "admin@example.com"        # For notifications
```

**Don't know what to set?**
- `app_name`: Use your application name (lowercase, no spaces)
- `s3_bucket_name`: Must be **globally unique** across all AWS accounts. Use format: `yourname-appname-year`
- `server_name`: Use `"_"` if you're just using IP address. Use domain if you have one.

### Step 3: Create Secrets Vault

```bash
# Create vault password file (stores your vault encryption password)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Edit secrets vault
nano group_vars/vault.yml
```

**Required secrets:**

```yaml
---
# Git Repository
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app.git"
vault_git_branch: "main"

# AWS Settings
vault_aws_region: "us-east-2"

# S3 Configuration
vault_s3_bucket_name: "yourname-myapp-2026"
vault_s3_folder: "data"

# Application Credentials
vault_app_username: "admin"              # Default login username
vault_app_password: "secure-password"    # Default login password (change after deploy)
```

**Where to get these:**
- `vault_git_repo`: Your GitHub repository URL (create if needed)
- `vault_aws_region`: Same as `aws_region` in `all.yml`
- `vault_s3_bucket_name`: Same as `s3_bucket_name` in `all.yml`
- `vault_app_username`: Login username you want for the app
- `vault_app_password`: Strong password (will change after deployment)

### Step 4: Verify Configuration

```bash
cd deployment

# Check vault can be decrypted
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass
# Should show your secrets without error

# Check configuration file exists
cat group_vars/all.yml | head -20
# Should show your variables

# Verify AWS CLI uses correct profile
aws sts get-caller-identity --profile your-profile-name
# Should show your account ID and IAM user
```

---

## Verification Checklist

**Before you start deployment, verify everything:**

```bash
# 1. AWS CLI working
aws sts get-caller-identity
# ✅ Shows your account ID and IAM user

# 2. Ansible installed
ansible --version
# ✅ Shows version 2.9 or higher

# 3. Python installed
python3 --version
# ✅ Shows version 3.8 or higher

# 4. Git configured
git config --global user.name
git config --global user.email
# ✅ Both return values

# 5. Deployment requirements installed
cd deployment
pip3 list | grep boto
# ✅ Shows boto3 and other AWS packages

# 6. Configuration created
ls deployment/group_vars/all.yml
ls deployment/group_vars/vault.yml
# ✅ Both files exist

# 7. Vault can be read
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass
# ✅ Shows your secrets without error

# 8. SSH key doesn't exist yet (will be created)
ls ~/.ssh/{app_name}-key.pem
# ✅ Should NOT exist yet (will be created during deployment)
```

**If all checks pass ✅ you're ready to deploy!**

**Next step:** → [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) or [QUICKSTART.md](QUICKSTART.md)

---

## Troubleshooting

### AWS CLI Issues

**"Unable to locate credentials"**
```bash
# Make sure you ran aws configure
aws configure
# Then test
aws sts get-caller-identity
```

**"InvalidUserID.Malformed"**
- Your IAM user doesn't exist
- Create it in [IAM Console](https://console.aws.amazon.com/iam/home#/users)

**"SignatureDoesNotMatch"**
- Your Access Key or Secret Key is wrong
- Double-check the `.csv` file you downloaded
- Create new access keys if needed

### Ansible Issues

**"ansible: command not found"**
```bash
# Install Ansible
pip3 install ansible

# Or using your system package manager
# macOS: brew install ansible
# Ubuntu: sudo apt install ansible
```

**"No module named 'boto3'"**
```bash
# Install deployment requirements
cd deployment
pip3 install -r requirements.txt
```

### Configuration Issues

**"Cannot access vault.yml - Permission denied"**
```bash
# Check vault password file permissions
ls -la ~/.vault_pass
# Should show: -rw------- (600)

# Fix permissions
chmod 600 ~/.vault_pass
```

**"Vault password not found"**
```bash
# Create vault password file
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

---

## What's Next?

**All prerequisites met? Choose your deployment path:**

- **Fast deployment (15-20 min):** → [QUICKSTART.md](QUICKSTART.md)
- **Educational step-by-step (1-2 hours):** → [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)
- **Understand everything first:** → [ARCHITECTURE.md](../reference/ARCHITECTURE.md)

---

## Summary

You've now:
- ✅ Created AWS account and IAM user
- ✅ Configured AWS CLI with credentials
- ✅ Installed local deployment tools
- ✅ Created deployment configuration files
- ✅ Verified everything works

**You're ready to deploy!**

