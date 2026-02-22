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
   - `CloudWatchLogsFullAccess` - Application logs
   
   **Optional but recommended for production:**
   - Create an inline policy for CloudWatch alarms (see [Alarms section](#alarms-required-for-cloudwatch-alarms) below for details)

8. Click **Next: Tags** (skip)
9. Click **Create user**

#### Alarms: Required for CloudWatch Alarms

**CloudWatch** is AWS's logging and monitoring service. Think of it as:
- **Centralized log storage** - All your app logs in one place
- **Searchable** - Find errors across days of logs instantly
- **Metrics** - Track performance (response time, errors, requests)
- **Alarms** - Automated alerts when something goes wrong
- **Dashboards** - Visual monitoring of key metrics

**Three separate capabilities:**

1. **Logs** (CloudWatchLogsFullAccess - AWS Managed Policy) ✅ REQUIRED
   - ✅ Write application logs to CloudWatch
   - ✅ Create log groups (organize logs)
   - ✅ View/search logs
   - What it does: Application automatically sends logs → You can view them anytime
   - Required: **YES** - for application to send logs

2. **Alarms** (Custom inline policy needed - no AWS managed policy) ⚠️ OPTIONAL
   - ✅ Create automated alarms
   - ✅ Send notifications (email, SNS, etc.)
   - ✅ Alert you to attacks, failures, high CPU/memory
   - What it does: Monitor metrics 24/7 → Alert you automatically if problems detected
   - Required: **NO** - but HIGHLY RECOMMENDED for production
   - AWS managed policy: **NONE EXISTS** - Create inline policy instead
   
   **To add alarm permissions, create inline policy:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "cloudwatch:PutMetricAlarm",
           "cloudwatch:DeleteAlarms",
           "cloudwatch:DescribeAlarms",
           "cloudwatch:GetMetricStatistics",
           "cloudwatch:ListMetrics"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
   
   How to attach:
   1. Go to [IAM Users](https://console.aws.amazon.com/iam/home#/users)
   2. Select your user
   3. Click **Add inline policy**
   4. Choose **JSON** and paste above policy
   5. Name it: `CloudWatchAlarmPolicy`
   6. Click **Create policy**

3. **Dashboards** (CloudWatchDashboardsFullAccess - part of CloudWatchFullAccess)
   - ✅ Create visual dashboards
   - ✅ Display metrics, logs, alarms
   - ✅ Custom widgets and layouts
   - What it does: Pretty visualizations of your app health
   - Required: **NO** - optional but useful for status at a glance

**Deployment includes:**
- ✅ CloudWatch agent (sends logs automatically)
- ✅ Basic log rotation (keeps logs manageable)
- ❌ Alarms (you create these with inline policy)
- ❌ Dashboards (you create these manually)

**What you get with required permissions:**
- `CloudWatchLogsFullAccess` = Application logs automatically collected and searchable

**What you need to add for production:**
- Inline policy for alarms (see above) = 24/7 automated monitoring and alerts

**How logs flow:**
1. Your application runs on EC2
2. Application writes to `/var/log/{app_name}/`
3. CloudWatch agent (installed during deployment) reads those logs automatically
4. Logs sent to CloudWatch Logs service
5. You can:
   - View them in AWS Console → CloudWatch → Logs → `/{app_name}/`
   - Create alarms based on log patterns ("alert me if 5xx errors spike")
   - Create dashboards showing error counts, request rates, etc.

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

**Key variables to change (at top of file):**

```yaml
# ============================================================================
# APPLICATION IDENTITY (REQUIRED)
# ============================================================================

app_name: "myapp"                       # CHANGE THIS - Your app's technical name
                                        # Examples: myapp, comic_tracker, inventory_tool
                                        # Used for: service name, directories, logs, etc.

app_display_name: "My Application"      # CHANGE THIS - Your app's display name
                                        # Examples: "My App", "Comic Tracker", "Inventory Tool"

server_name: "_"                        # CHANGE THIS - Domain or "_" for IP-only access
                                        # "_" = access via IP only (no SSL)
                                        # "your-domain.com" = use domain with SSL

ssl_email: "admin@example.com"          # CHANGE THIS - Email for SSL certificate alerts
                                        # Only needed if using SSL (server_name is not "_")

# ============================================================================
# USERS (OPTIONAL - defaults are secure)
# ============================================================================

admin_user: ubuntu                      # Admin/SSH user for deployment
                                        # This user can SSH and manage the server
                                        # Default: ubuntu (standard for Ubuntu EC2 AMI)

app_user: "{{ app_name }}"              # Application runtime user (restricted, no SSH access)
                                        # This user runs the application process
                                        # Default: same as app_name
                                        # Uncomment and change if you want different username:
                                        # app_user: "myapp_runtime"

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

git_branch: main                        # Git branch to deploy
                                        # (usually: main or master)
                                        # Your GitHub repo URL is in vault.yml

# ============================================================================
# PERFORMANCE SETTINGS (OPTIONAL)
# ============================================================================

gunicorn_workers: 4                     # Number of worker processes
                                        # Typical: 2-4 x CPU cores
python_version: "3.10"                  # Python version to use

# ============================================================================
# LOG & BACKUP SETTINGS (OPTIONAL)
# ============================================================================

log_retention_days: 20                  # Days to keep logs
log_max_size: "10M"                     # Max size per log file
backup_retention_days: 30               # Days to keep backups
s3_version_retention_days: 30           # Days to keep old S3 versions

# ============================================================================
# ADVANCED SETTINGS (OPTIONAL - Production Use)
# ============================================================================

ec2_instance_type: "t3.micro"           # EC2 server instance type
                                        # Keep as t3.micro for free tier
                                        # Change for production: t3.small, t3.medium, etc.
                                        # Note: Larger = higher monthly cost

cloudfront_price_class: "PriceClass_100" # CloudFront pricing tier (if using CDN)
                                        # PriceClass_100: US, Canada, Europe (cheapest)
                                        # PriceClass_200: Above + Asia, Africa, Middle East, South America
                                        # PriceClass_All: All worldwide locations (most expensive)
                                        # Only matters if you use setup-cloudfront.yml
```

**Don't know what to set?**
- `app_name`: Your application name (lowercase, no spaces). Example: `myapp`, `comic_tracker`
- `app_display_name`: Friendly display name. Example: `"My Application"`, `"Comic Tracker"`
- `server_name`: Use `"_"` if you're just using IP address. Use `"your-domain.com"` if you have a domain.
- `ssl_email`: Email for Let's Encrypt certificate notifications (only needed if using domain)
- `admin_user`: Leave as `ubuntu` (default for Ubuntu 22.04 AMI, used for SSH and deployment)
- `app_user`: Automatically set to `app_name` - this user runs your application (no SSH access, no shell)

### Step 3: Create & Encrypt Secrets Vault

**⚠️ SECURITY:** The vault file contains secrets. You MUST encrypt it.

#### Step 3a: Create Vault Password File

This is your master password for encrypting/decrypting secrets:

```bash
# Create vault password file (stores your vault encryption password)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

**⚠️ IMPORTANT:**
- `your-secure-password` - Make this a STRONG random password
- Save it somewhere secure (password manager, etc.)
- This password is needed every time you run deployment playbooks
- This is NOT your AWS password - it's just for Ansible vault encryption

#### Step 3b: Copy & Edit Vault

```bash
cd deployment

# Copy template to your config
cp group_vars/vault.yml.example group_vars/vault.yml

# Edit with your secrets (plain text for now)
nano group_vars/vault.yml
```

**All required vault variables:**

```yaml
---
# ============================================================================
# GIT REPOSITORY (REQUIRED)
# ============================================================================
# Where your application code is stored on GitHub
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app.git"

# ============================================================================
# AWS CONFIGURATION (REQUIRED)
# ============================================================================
# These values configure where your data is stored and which region

vault_aws_region: "us-east-2"                   # Same region as your EC2 instance
                                                 # (should match aws configure region)

vault_s3_bucket_name: "yourname-myapp-2026"     # S3 bucket name (MUST BE GLOBALLY UNIQUE)
                                                 # Pattern: yourname-appname-year
                                                 # Used for: storing application data

vault_s3_folder: "data"                         # Folder within bucket
                                                 # Used for: organizing data in S3

# ============================================================================
# APPLICATION CREDENTIALS (REQUIRED)
# ============================================================================
# Default login credentials for your application
# You can change these after deployment

vault_app_username: "admin"                     # Default app login username
vault_app_password: "change-this-password"      # Default app login password
                                                 # IMPORTANT: Change this after first login

# ============================================================================
# SNS TOPIC (OPTIONAL - for monitoring and alerts)
# ============================================================================
# If you want to receive alerts (emails, SMS, etc.)
# Leave blank ("") if not needed
vault_sns_topic_arn: ""                         # Example: arn:aws:sns:us-east-2:123456789012:my-topic
```

**How to fill in each value:**

| Variable | Where to Get It | Example |
|----------|-----------------|---------|
| `vault_git_repo` | Your GitHub repo URL | `https://github.com/myusername/myapp.git` |
| `vault_aws_region` | Same as AWS CLI region | `us-east-2` |
| `vault_s3_bucket_name` | Create a unique name | `john-myapp-2026` |
| `vault_s3_folder` | Choose folder name | `data` or `uploads` |
| `vault_app_username` | Choose app login | `admin` or `myusername` |
| `vault_app_password` | Create strong password | `Tr0pic@lBanana99!` |
| `vault_sns_topic_arn` | Optional - skip if not using | Leave as empty string `""` |

**IMPORTANT about S3 bucket name:**
- Must be **globally unique** across ALL AWS accounts (not just yours)
- Can only contain lowercase letters, numbers, and hyphens
- Cannot start or end with a hyphen
- 3-63 characters long
- Recommended pattern: `yourname-appname-year` (e.g., `john-myapp-2026`)

#### Step 3c: Encrypt the Vault File

**NOW encrypt your vault.yml file:**

```bash
cd deployment

# Encrypt vault.yml with your vault password
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default

# Verify it's encrypted (should show encrypted content, not plain text)
cat group_vars/vault.yml | head -5
# Should show: $ANSIBLE_VAULT;1.1;AES256;... (not readable plain text)

# Verify you can decrypt it
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass
# Should show your secrets in plain text
```

**Vault Security:**
- ✅ Your vault.yml is now encrypted on disk
- ✅ Only readable with the vault password from ~/.vault_pass
- ✅ Safe to commit to Git (though ignored by .gitignore)
- ✅ GitHub credentials and AWS settings stay private
- ✅ Playbooks automatically decrypt it with ~/.vault_pass

**⚠️ CRITICAL - Save Your Vault Password:**
- Store `~/.vault_pass` securely (don't lose this file!)
- Back up your vault password in a password manager
- If you lose it, you cannot decrypt vault.yml

### Step 4: Verify Configuration

```bash
cd deployment

# 1. Check all.yml exists and shows your settings
grep -E "^app_name:|^app_display_name:|^server_name:|^admin_user:|^app_user:" group_vars/all.yml
# Should show your values

# 2. Check vault.yml is encrypted
file group_vars/vault.yml
# Should show: vault.yml: ASCII text (encrypted vault file)
# OR check first line:
head -1 group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.2;AES256; (encryption header, not plain text)

# 3. Verify vault can be decrypted with your password
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | head -5
# Should show your secrets without error (looking for vault_git_repo, vault_aws_region, etc.)

# 4. Verify AWS CLI uses correct profile/region
aws sts get-caller-identity
# Should show your account ID and IAM user

# 5. Verify all configuration files exist and have correct permissions
ls -la group_vars/all.yml group_vars/vault.yml ~/.vault_pass
# Should show:
#  - group_vars/all.yml (readable)
#  - group_vars/vault.yml (readable)
#  - ~/.vault_pass with -rw------- permissions (600)
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

# 7. ⚠️ VAULT IS ENCRYPTED (CRITICAL!)
head -1 deployment/group_vars/vault.yml
# ✅ Should show: $ANSIBLE_VAULT;1.2;AES256; (NOT plain text!)
# ✅ If it shows plain YAML, run: ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass

# 8. Vault password file exists and has correct permissions
ls -la ~/.vault_pass
# ✅ Should show: -rw------- (read/write for user only, not readable by others)

# 9. Vault can be decrypted
ansible-vault view deployment/group_vars/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# ✅ Should show your GitHub repo URL without error

# 10. SSH key doesn't exist yet (will be created)
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

## ✅ Prerequisites Complete!

You've successfully set up:
- ✅ AWS account with IAM user
- ✅ AWS CLI configured and working
- ✅ Local tools installed (Python, Ansible, Git)
- ✅ Deployment configuration (`all.yml`)
- ✅ Encrypted secrets vault (`vault.yml`)
- ✅ Vault password file (`~/.vault_pass`)

**Everything is ready to deploy your application!**

---

## 🚀 Choose Your Next Step

Now that prerequisites are complete, choose how you want to deploy:

### Option 1: Fast & Automated (Recommended) - 15-20 minutes

**One command deploys everything automatically**

→ **[QUICKSTART.md](QUICKSTART.md)**

Best for:
- ✅ Getting your app running quickly
- ✅ New to cloud deployment
- ✅ Want everything automated

What it does:
- Creates AWS infrastructure (S3, IAM, Security Group, EC2)
- Configures your application
- Sets up web server and app server
- Saves server info for you to access

### Option 2: Learn Step-by-Step - 1-2 hours

**Deploy manually with full explanations of each step**

→ **[MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)**

Best for:
- ✅ Learning how deployment works
- ✅ Understanding each AWS component
- ✅ Custom configuration needs
- ✅ Troubleshooting issues

What it includes:
- Step-by-step creation of each resource
- Multiple options for each step (Playbook/CLI/Console)
- Educational explanations
- Links to AWS documentation

### Option 3: Understand the Architecture First

**Learn about all components before deploying**

→ **[ARCHITECTURE.md](../reference/ARCHITECTURE.md)**

Best for:
- ✅ Understanding the whole system
- ✅ Advanced customization needs
- ✅ Decision-making about infrastructure

---

## ⏭️ I'm Ready - Take Me There!

**Quick decision:**

| I want to... | Go to... | Time |
|---|---|---|
| Deploy my app NOW | [QUICKSTART.md](QUICKSTART.md) | 15-20 min |
| Learn how to deploy | [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) | 1-2 hours |
| Understand the system | [ARCHITECTURE.md](../reference/ARCHITECTURE.md) | 30 min |

---

**Pick one above and click the link. That's it!**

---

## Troubleshooting Prerequisites

Still having issues? Check these:

### AWS CLI Not Working

```bash
aws sts get-caller-identity
# ✅ Should show your account ID
# ❌ If it doesn't, see: AWS CLI Configuration section above
```

### Vault Issues

```bash
# Check vault is encrypted
head -1 deployment/group_vars/vault.yml
# ✅ Should show: $ANSIBLE_VAULT;1.1;AES256

# Check vault can be decrypted
ansible-vault view deployment/group_vars/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# ✅ Should show your GitHub URL
```

### Ansible Not Working

```bash
ansible --version
# ✅ Should show version 2.9+

# If not, install it:
pip3 install ansible
```

### Configuration Files Missing

```bash
ls -la deployment/group_vars/all.yml deployment/group_vars/vault.yml
# ✅ Both should exist

# If not, run:
cd deployment/scripts
bash local-dev-setup.sh
```

---

**Still stuck?** Each deployment guide has a Troubleshooting section with more help.

---

## Reference

**Configuration file location:** `deployment/group_vars/`

- `all.yml` - Your app settings (not in Git)
- `all.yml.example` - Template (in Git, shows what variables exist)
- `vault.yml` - Your secrets, encrypted (not in Git)
- `vault.yml.example` - Template (in Git, shows what secrets you need)

**Vault password file:** `~/.vault_pass` (your home directory, not in Git)

