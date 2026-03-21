# Chapter 1: Prerequisites

Set up your AWS account, local tools, and configuration files.

---

## Table of Contents

1. [AWS Account Setup](#aws-account-setup)
2. [AWS CLI Configuration](#aws-cli-configuration)
3. [Local Tools Installation](#local-tools-installation)
4. [Deployment Configuration](#deployment-configuration)
5. [Verification](#verification)

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

### Step 2: Create IAM Deployer User

**Why:** Root account should only be used for initial setup. Create a limited IAM user for all deployment work.

#### Option A: Ansible Playbook (Recommended)

The playbook creates the user, attaches all required policies (including CloudWatch alarms), and generates access keys in one step.

> **Note:** `vault.yml` does not exist yet at this stage, so you pass your app name directly on the command line.

```bash
# Configure AWS CLI with root credentials temporarily
aws configure
# Enter your root access key, secret key, region (e.g., us-east-2), and json

# Run the playbook (replace {app_name} with your actual app name, e.g., rampe)
cd deployment
ansible-playbook playbooks/create-iam-user.yml -e app_name={app_name}
```

The playbook creates `{app_name}-deployer` with these permissions:
- `AmazonEC2FullAccess` — create/manage EC2 instances
- `AmazonS3FullAccess` — create/manage S3 buckets
- `IAMFullAccess` — create/manage IAM roles
- `SecretsManagerReadWrite` — manage secrets
- `CloudWatchLogsFullAccess` — application logs
- `CloudWatchAlarmPolicy` (inline) — monitoring alarms and metrics

**Save the access key and secret key** printed at the end — they cannot be retrieved again.

#### Option B: AWS Console (Manual)

1. Go to [IAM Console](https://console.aws.amazon.com/iam/home#/users)
2. Click **Create User**
3. User name: `{app_name}-deployer`
4. Check **Access key - Programmatic access**
5. Click **Attach existing policies directly** and search for each:
   - `AmazonEC2FullAccess`
   - `AmazonS3FullAccess`
   - `IAMFullAccess`
   - `SecretsManagerReadWrite`
   - `CloudWatchLogsFullAccess`
6. Create the user, then **download the .csv** with the access keys

After creating the user manually, add the CloudWatch alarms inline policy:
1. Select the user → **Add inline policy** → **JSON**
2. Paste:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "cloudwatch:PutMetricAlarm",
         "cloudwatch:DeleteAlarms",
         "cloudwatch:DescribeAlarms",
         "cloudwatch:GetMetricStatistics",
         "cloudwatch:ListMetrics"
       ],
       "Resource": "*"
     }]
   }
   ```
3. Name it `CloudWatchAlarmPolicy` and save.

### Step 3: Save and Switch to Deployer Credentials

**IMPORTANT:** Save the Access Key ID and Secret Access Key immediately. You will not see them again.

Store both values in a password manager or other secure location.

⚠️ **NEVER commit these to Git or share them.**

Now reconfigure the AWS CLI to use the deployer credentials instead of root:

```bash
aws configure
# Enter the deployer user's access key, secret key, region, json
```

After this point, all AWS operations use the limited deployer account.

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

**For detailed setup:** → Configure AWS CLI profiles for your region and account

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

### Step 3: Configure Git (Optional but Recommended)

Configure git to use your identity automatically:

```bash
cd deployment
./scripts/configure-git.sh
```

**That's it!** Your commits will now use `{app_name}@brianeckblad.dev`

**What it does:**
- ✅ Reads your app name from deployment config
- ✅ Automatically sets email to `rampe@brianeckblad.dev` (for rampe project)
- ✅ Sets name to "Brian Eckblad"
- ✅ Configures locally (this repo only)

**Want more options?** → [GIT_CONFIGURATION.md](GIT_CONFIGURATION.md)
- Global configuration (all repos)
- Manual app name specification
- Verify it's working

### Step 4: Install Deployment Requirements

```bash
# Navigate to deployment directory
cd /path/to/{app_name}/deployment

# Install Python requirements (Ansible plugins, AWS SDK, etc.)
pip3 install -r requirements.txt

# Install/upgrade Ansible collections (AWS modules)
ansible-galaxy collection install -r requirements.yml --upgrade

# Verify Ansible
ansible --version

# Verify Ansible can run playbooks
ansible-playbook --version
```

---

## Deployment Configuration

**Create your personal deployment settings (not tracked in Git)**

### Updating Existing Configuration?

If you already have `vault.yml`, merge it with the new template:

```bash
cd deployment
./scripts/local-dev-setup.sh -merge
```

This automatically imports your existing values into updated templates. You only add new values instead of retyping everything.

→ [Using local-dev-setup.sh](#step-1-use-configuration-templates) (both new and merge modes)

---

### Step 1: Use Configuration Templates

The `local-dev-setup.sh` script handles both new setup and merging:

```bash
cd deployment

# Interactive mode (auto-detects if files exist)
./scripts/local-dev-setup.sh

# OR explicitly choose:

# Option A: Create fresh from templates
./scripts/local-dev-setup.sh -new

# Option B: Merge existing values with updated templates
./scripts/local-dev-setup.sh -merge
```

**This creates/updates:**
- `group_vars/vault.yml` - All deployment configuration (encrypted, safe to commit)

**Why encrypted?** The vault contains identity, credentials, and infrastructure details. Encrypting lets you commit it to Git safely.

### Step 2: Edit & Encrypt Vault

`vault.yml` is the single source of truth for all deployment configuration — identity, credentials, tuning, and infrastructure sizing.

#### Step 2a: Create Vault Password File

This is your master password for encrypting/decrypting the vault:

```bash
# Create vault password file (OPTIONAL but RECOMMENDED - for convenience)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

**About the vault password file:**
- ✅ **If you create it** (`~/.vault_pass`) - Playbooks run automatically without prompting
- ✅ **If you skip it** - Playbooks will prompt you to type the password when needed
- ⚠️ **Make it strong** - Use a random, secure password (different from other passwords)
- ⚠️ **Save it** - Store it in a password manager or secure location
- ⚠️ **File permissions** - Must be `600` (readable only by you)

**Why create it?**
- Convenience: No password prompt on every playbook run
- Automation: Useful for CI/CD pipelines
- Security: Password is only in one place, not typed repeatedly

**Why skip it?**
- Security: Don't store password in a file on disk
- Simplicity: Just type password when prompted
- Flexibility: Different password per deployment if needed

#### Step 2b: Copy & Edit Vault

```bash
cd deployment

# Copy template to your config
cp group_vars/vault.yml.example group_vars/vault.yml

# Edit with your values (plain text for now)
nano group_vars/vault.yml
```

**Key variables to set (see vault.yml.example for full list):**

```yaml
---
# ============================================================================
# GIT REPOSITORY (REQUIRED)
# ============================================================================
git_repo_url: "https://github.com/YOUR_USERNAME/your_app.git"

# ============================================================================
# AWS CONFIGURATION (REQUIRED)
# ============================================================================
aws_region: "us-east-2"                         # Same region as your EC2 instance

s3_bucket_name: "yourname-myapp-2026"           # S3 bucket name (MUST BE GLOBALLY UNIQUE)
                                                 # Pattern: yourname-appname-year

s3_folder: "data"                               # Folder within bucket

# ============================================================================
# APPLICATION CREDENTIALS (REQUIRED)
# ============================================================================
app_default_username: "admin"                   # Default app login username
app_default_password: "change-this-password"    # Default app login password

# ============================================================================
# SNS TOPIC (OPTIONAL - for monitoring and alerts)
# ============================================================================
sns_topic_arn: ""                               # Example: arn:aws:sns:us-east-2:123456789012:my-topic
```

**How to fill in each value:**

| Variable | Where to Get It | Example |
|----------|-----------------|---------|
| `git_repo_url` | Your GitHub repo URL | `https://github.com/myusername/myapp.git` |
| `aws_region` | Same as AWS CLI region | `us-east-2` |
| `s3_bucket_name` | Create a unique name | `john-myapp-2026` |
| `s3_folder` | Choose folder name | `data` or `uploads` |
| `app_default_username` | Choose app login | `admin` or `myusername` |
| `app_default_password` | Create strong password | `Tr0pic@lBanana99!` |
| `sns_topic_arn` | Optional - skip if not using | Leave as empty string `""` |

**IMPORTANT about S3 bucket name:**
- Must be **globally unique** across ALL AWS accounts (not just yours)
- Can only contain lowercase letters, numbers, and hyphens
- Cannot start or end with a hyphen
- 3-63 characters long
- Recommended pattern: `yourname-appname-year` (e.g., `john-myapp-2026`)

#### Step 2c: Encrypt the Vault File

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
- ✅ Only readable with the vault password
- ✅ Safe to commit to Git (encrypted content is unreadable)
- ✅ All identity, credentials, and infrastructure details stay private
- ✅ Playbooks automatically decrypt with password from `~/.vault_pass` OR prompt if missing

**⚠️ CRITICAL - Save Your Vault Password:**
- Store `~/.vault_pass` securely (don't lose this file!)
- Back up your vault password in a password manager
- If you lose it, you cannot decrypt vault.yml

### Step 3: Verify Configuration

```bash
cd deployment

# 1. Check vault.yml is encrypted
head -1 group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.2;AES256; (encryption header, not plain text)

# 2. Verify vault can be decrypted and shows your variables
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | head -20
# Should show: app_name, server_name, git_repo_url, etc.

# 3. Verify AWS CLI uses correct profile/region
aws sts get-caller-identity
# Should show your account ID and IAM user

# 4. Verify configuration files exist and have correct permissions
ls -la group_vars/vault.yml ~/.vault_pass
# Should show:
#  - group_vars/vault.yml (readable)
#  - ~/.vault_pass with -rw------- permissions (600)
```

---

## Verification

Run these checks before continuing. Every command should succeed.

```bash
aws sts get-caller-identity           # Shows your account ID
ansible --version                     # Version 2.9+
python3 --version                     # Version 3.8+

cd deployment
head -1 group_vars/vault.yml          # Shows $ANSIBLE_VAULT;1.2;AES256
ls -la ~/.vault_pass                  # Permissions: -rw-------

source scripts/load-vars.sh           # Shows variables loaded
echo $app_name                        # Shows your application name
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Unable to locate credentials` | Run `aws configure` and enter your access key |
| `ansible: command not found` | `pip3 install ansible` |
| `No module named 'boto3'` | `cd deployment && pip3 install -r requirements.txt` |
| `Cannot access vault.yml` | `chmod 600 ~/.vault_pass` |
| Vault shows plain text, not `$ANSIBLE_VAULT` | `ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass` |
| `source scripts/load-vars.sh` fails | Make sure you are in the `deployment/` directory |

---

## Next step

Continue to [Chapter 2: Quick Start](QUICKSTART.md) (automated, 15–20 min) or [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) (step-by-step, 1–2 hrs).

