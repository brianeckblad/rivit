# Chapter 1: Prerequisites

Set up your AWS account, local tools, and configuration files.

---

## Table of Contents

1. [AWS Account Setup](#aws-account-setup)
2. [AWS CLI Configuration](#aws-cli-configuration)
3. [Local Tools Installation](#local-tools-installation)
4. [Deployment Configuration](#deployment-configuration)
5. [Create IAM Deployer User](#create-iam-deployer-user)
6. [Verification](#verification)

---

## AWS Account Setup

**If you already have an AWS account and CLI configured, skip to [Local Tools Installation](#local-tools-installation).**

### Step 1: Create AWS Account

1. Go to [AWS Console](https://aws.amazon.com) and click **Create an AWS Account**
2. Follow the wizard — email, password, payment method, identity verification
3. Note your **AWS Account ID** from [Account settings](https://console.aws.amazon.com/billing/home#/account)

> **Best practice:** Never use the root account for daily work. You will create a limited deployer user later in this chapter.

### Step 2: Create a Temporary Access Key

You need a short-lived root credential to bootstrap the deployer user.

1. Sign in to the AWS Console as root
2. Click your account name (top-right) → **Security credentials**
3. Under **Access keys**, click **Create access key** and acknowledge the warning
4. **Save the Access Key ID and Secret Access Key** — you need them in the next step

---

## AWS CLI Configuration

### Step 1: Install AWS CLI

**macOS:**
```bash
brew install awscli
aws --version
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt install -y awscli
```

### Step 2: Configure CLI with temporary root credentials

```bash
aws configure

AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-2
Default output format [None]: json
```

### Step 3: Verify

```bash
aws sts get-caller-identity
# Arn should show: arn:aws:iam::123456789012:root
```

---

## Local Tools Installation

| Tool | Purpose | Min Version |
|------|---------|------------|
| **Python** | Runtime for deployment tools | 3.8+ |
| **Ansible** | Automation | 2.9+ |
| **Git** | Version control | 2.x |

### Install

**macOS:**
```bash
brew install python3 ansible git
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install -y python3 python3-pip git ansible
```

### Install deployment requirements

```bash
cd /path/to/{app_name}/deployment

# Python packages (Ansible plugins, AWS SDK)
pip3 install -r requirements.txt

# Ansible collections (AWS Ansible modules)
ansible-galaxy collection install -r requirements.yml --upgrade
```

### Configure Git (optional)

```bash
cd deployment
./scripts/configure-git.sh
```

---

## Deployment Configuration

### Step 1: Create vault.yml

```bash
cd deployment
cp group_vars/vault.yml.example group_vars/vault.yml

# Edit values
nano group_vars/vault.yml
```

**Required variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `app_name` | Technical identifier | `myapp` |
| `server_name` | Domain for SSL | `myapp.example.com` |
| `ssl_email` | Let's Encrypt contact | `you@example.com` |
| `git_repo_url` | Git repository URL | `https://github.com/user/repo.git` |
| `aws_region` | AWS region | `us-east-2` |
| `s3_bucket_name` | S3 bucket (globally unique) | `john-myapp-2026` |
| `app_default_username` | App login username | `admin` |
| `app_default_password` | App login password | `Str0ng!Pass` |
| `server_iam_role_name` | Shared server's IAM role name | `shared-server-ec2-role` |
| `gunicorn_port` | Unique port per app | `8000` |

> **S3 bucket names** must be globally unique across all AWS accounts. Use the pattern `yourname-appname-year`.

> **gunicorn_port** must be unique on the shared server. Assign sequentially: app1=8000, app2=8001, app3=8002.

### Step 2: Create vault password file

```bash
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Save the password in a password manager — if the file is lost, vault.yml cannot be decrypted.

### Step 3: Encrypt the vault

```bash
cd deployment
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass
```

Verify encryption:

```bash
head -1 group_vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

---

## Create IAM Deployer User

Replace the temporary root credentials with a limited deployer account.

### Option A: Ansible Playbook (recommended)

```bash
cd deployment
ansible-playbook playbooks/create-iam-user.yml --vault-password-file ~/.vault_pass
```

Creates `{app_name}-deployer` with these permissions:
- `AmazonS3FullAccess` — create/manage S3 buckets and objects
- `IAMFullAccess` — create/manage IAM policies
- `SecretsManagerReadWrite` — manage secrets
- `CloudWatchLogsFullAccess` — application logs
- `CloudWatchAlarmPolicy` (inline) — monitoring alarms and metrics

**Save the Access Key ID and Secret Key** printed at the end.

### Option B: AWS Console (manual)

1. Go to [IAM Console](https://console.aws.amazon.com/iam/home#/users) → **Create User**
2. User name: `{app_name}-deployer`
3. Attach these managed policies:
   - `AmazonS3FullAccess`
   - `IAMFullAccess`
   - `SecretsManagerReadWrite`
   - `CloudWatchLogsFullAccess`
4. Create the user and download the CSV with access keys

### Switch to deployer credentials

```bash
aws configure
# Enter the deployer user's access key, secret key, region, json format
```

Verify:

```bash
aws sts get-caller-identity
# Arn should show: arn:aws:iam::123456789012:user/{app_name}-deployer
```

### Delete the temporary root access key

1. Sign in to the AWS Console as root
2. Click account name → **Security credentials**
3. Under **Access keys** → **Actions → Delete** the key you created earlier

---

## Verification

Run these checks before continuing. Every command should succeed.

```bash
aws sts get-caller-identity           # Shows deployer user, not root
ansible --version                     # Version 2.9+
python3 --version                     # Version 3.8+

cd deployment
head -1 group_vars/vault.yml          # Shows $ANSIBLE_VAULT;1.2;AES256
ls -la ~/.vault_pass                  # Permissions: -rw-------

source scripts/load-vars.sh           # Shows variables loaded successfully
echo $app_name                        # Shows your application name
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Unable to locate credentials` | Run `aws configure` |
| `ansible: command not found` | `pip3 install ansible` |
| `No module named boto3` | `cd deployment && pip3 install -r requirements.txt` |
| `Cannot access vault.yml` | `chmod 600 ~/.vault_pass` |
| Vault shows plain text | `ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass` |
| `source scripts/load-vars.sh` fails | Confirm you are in the `deployment/` directory |

---

## Next step

Continue to [Chapter 2: Quick Start](QUICKSTART.md) (automated, 10–15 min) or [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) (step-by-step, 30–60 min).
