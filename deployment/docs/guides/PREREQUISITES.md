# Chapter 1: Prerequisites

Set up your AWS account, local tools, and configuration files before running any playbook.

---

## Local Tools

| Tool | Purpose | Minimum version |
|------|---------|----------------|
| Python 3 | Ansible runtime, deployment scripts | 3.8+ |
| Ansible | Playbook automation | 2.9+ |
| AWS CLI | Create S3, IAM, Secrets Manager resources | 2.x |
| Git | Source control | 2.x |

**macOS:**
```bash
brew install python3 ansible git awscli
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y python3 python3-pip git ansible awscli
```

**Install deployment Python packages and Ansible collections:**
```bash
cd /path/to/project/deployment
pip3 install -r requirements.txt
ansible-galaxy collection install -r requirements.yml --upgrade
```

---

## AWS Account Setup

**If you already have an AWS account and CLI configured, skip to [Deployment Configuration](#deployment-configuration).**

### Step 1: Create AWS account

Go to [aws.amazon.com](https://aws.amazon.com) → **Create an AWS Account**. Note your **AWS Account ID** from [Account settings](https://console.aws.amazon.com/billing/home#/account).

> **Best practice:** Never use the root account for daily work. You will create a limited deployer user below.

### Step 2: Bootstrap with temporary root credentials

1. Sign in to the AWS Console as root
2. Click your account name (top-right) → **Security credentials**
3. Under **Access keys**, click **Create access key** and save the values

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (e.g. us-east-2), format: json

aws sts get-caller-identity
# Arn should include :root
```

### Step 3: Create a limited deployer user

```bash
cd deployment
ansible-playbook playbooks/create-iam-user.yml --vault-password-file ~/.vault_pass
```

This creates `{app_name}-deployer` with these permissions:
`AmazonS3FullAccess`, `IAMFullAccess`, `SecretsManagerReadWrite`, `CloudWatchLogsFullAccess`

Save the Access Key ID and Secret Key printed at the end.

```bash
aws configure
# Enter the deployer user credentials

aws sts get-caller-identity
# Arn should show: arn:aws:iam::ACCOUNT_ID:user/{app_name}-deployer
```

Then delete the temporary root access key in the AWS Console.

---

## Deployment Configuration

### Step 1: Copy the vault template

```bash
cd deployment
cp group_vars/vault.yml.example group_vars/vault.yml
```

### Step 2: Fill in all variables

Edit `group_vars/vault.yml`. Every variable is required unless marked optional.

#### Application identity

| Variable | Description | Example |
|----------|-------------|---------|
| `app_name` | Short technical identifier. Used in paths, service names, group names. No spaces. | `myapp` |
| `app_display_name` | Human-readable name shown in logs and supervisor output. | `My Inventory App` |
| `server_name` | Fully qualified domain name for nginx and SSL. | `myapp.example.com` |
| `ssl_email` | Email address for Let's Encrypt certificate renewal notifications. | `you@example.com` |

#### Server connection

| Variable | Description | Example |
|----------|-------------|---------|
| `server_host` | SSH hostname or IP address of the shared server. Find this in EC2 Console under the instance's **Public IPv4 address**. | `13.58.136.177` |
| `ssh_key_file` | Path to the SSH private key (`.pem` file) used to connect to the server. | `~/.ssh/myapp-key.pem` |
| `admin_user` | OS user that owns the application files and runs git commands. Usually `ubuntu` on AWS. | `ubuntu` |
| `app_user` | Dedicated unprivileged user that runs gunicorn. Created by `setup.yml`. | `myapp_runtime` |

#### AWS credentials and resources

| Variable | Description | How to get it |
|----------|-------------|---------------|
| `aws_region` | AWS region where all resources are created. | Choose based on your users' geography (e.g. `us-east-2` for Ohio). |
| `s3_bucket_name` | S3 bucket for app images and CSV backups. Must be globally unique across all AWS accounts. | Choose a name like `yourname-appname-2026`. |
| `s3_folder` | Top-level prefix inside the bucket. | Use `data` (default). |
| `secret_name` | AWS Secrets Manager secret path. Auto-derived as `{app_name}/production`. | Leave as the default: `"{{ app_name }}/production"` |
| `sns_topic_arn` | Optional SNS topic for error alerts. | Leave empty if not using alerts. |
| `server_iam_role_name` | IAM instance role currently attached to the shared EC2 server. `provision-app.yml` attaches this app's IAM policies to that role. Find it in EC2 Console → Instances → your server → **IAM role**. | `shared-server-ec2-role` or `""` to attach manually. |

#### Git repository

| Variable | Description | Example |
|----------|-------------|---------|
| `git_repo_url` | HTTPS URL of the application repository. | `https://github.com/user/myapp.git` |
| `git_branch` | Branch to deploy. | `main` |
| `git_token` | GitHub personal access token with `repo` scope. Needed to clone a private repository. Create at: GitHub → Settings → Developer settings → Personal access tokens. | `ghp_xxxxxxxxxxxx` |

#### Application credentials

| Variable | Description | Notes |
|----------|-------------|-------|
| `app_default_username` | Default login username created on first run. | `admin` |
| `app_default_password` | Default login password. Change this — do not use `admin`. | Min 12 chars, include symbols. |
| `users` | Colon-separated list of `username:password` pairs for additional accounts. | `alice:Pass1! brian:Pass2!` |

#### Flask runtime

| Variable | Description | Notes |
|----------|-------------|-------|
| `secret_key` | Flask session signing key. Must be random and secret. | Generate: `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `flask_env` | Flask environment. Always `production` on the server. | Leave as `production`. |

#### Port allocation (critical for shared servers)

| Variable | Description | Notes |
|----------|-------------|-------|
| `gunicorn_port` | Port gunicorn listens on (localhost only). **Must be unique across all apps on this server.** | Assign sequentially: `8000`, `8001`, `8002`, … |

> When adding a second app to the same server, the only field that changes in vault.yml is `gunicorn_port`. Assign the next unused port.

#### CloudFront CDN (optional)

| Variable | Description | Notes |
|----------|-------------|-------|
| `enable_cloudfront` | Set to `true` to create a CloudFront distribution. | `false` by default. |
| `cloudfront_domain` | Filled in after running `setup-cloudfront.yml`. Leave empty until then. | e.g. `d111111abcdef8.cloudfront.net` |
| `app_secret_token` | Shared random token between nginx and the app. | Generate: `openssl rand -hex 32` |

#### eBay API (if using eBay integration)

| Variable | Description | Where to get it |
|----------|-------------|-----------------|
| `ebay_environment` | `production` or `sandbox` | `production` for live sales. |
| `ebay_production_dev_id` | eBay Developer Program Dev ID. | [eBay Developers Program](https://developer.ebay.com) → My Account → Application Keys |
| `ebay_production_cert_id` | eBay Cert ID (client secret). | Same page as Dev ID. |
| `ebay_production_app_id` | eBay App ID (client ID). | Same page as Dev ID. |
| `ebay_production_token` | Per-user eBay auth token. | Generated via the eBay token flow. See `app/scripts/util-generate-ebay-token.sh`. |
| `ebay_verification_token` | Token for the eBay Marketplace Account Deletion webhook. | eBay Developer Console → Notifications. |

#### Tuning (usually left at defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `gunicorn_workers` | `4` | Number of gunicorn worker processes. Increase for high-traffic apps. |
| `gunicorn_timeout` | `120` | Request timeout in seconds. |
| `log_retention_days` | `20` | How many rotated log files to keep. |
| `log_max_size` | `10M` | Rotate log when it exceeds this size. |
| `backup_retention_days` | `30` | Delete S3 snapshots older than this many days. |

---

### Step 3: Create a vault password file

```bash
echo "your-secure-passphrase" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Save this passphrase in a password manager. If lost, the encrypted vault cannot be recovered.

### Step 4: Encrypt the vault

```bash
cd deployment
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass
```

Verify:

```bash
head -1 group_vars/vault.yml
# Should output: $ANSIBLE_VAULT;1.1;AES256
```

---

## Server Inventory

Copy the example inventory and set the server IP:

```bash
cd deployment
cp inventories/hosts.yml.example inventories/hosts.yml
```

Edit `inventories/hosts.yml` and set `ansible_host` to the value of `server_host` from vault.yml:

```yaml
ansible_host: 13.58.136.177          # your server_host value
ansible_ssh_private_key_file: ~/.ssh/your-key.pem   # your ssh_key_file value
```

Test connectivity:

```bash
ansible all -m ping --vault-password-file ~/.vault_pass
# Should return: server | SUCCESS
```

---

## Load Variables for CLI Use

Many shell commands in these guides use variables from vault.yml. Load them once per terminal session:

```bash
cd deployment
source scripts/load-vars.sh
echo $app_name      # e.g., myapp
echo $aws_region    # e.g., us-east-2
```

---

## Verification Checklist

Run these checks before continuing. Every command should succeed.

```bash
# AWS credentials
aws sts get-caller-identity

# Local tools
ansible --version       # 2.9 or higher
python3 --version       # 3.8 or higher

# Vault is encrypted
head -1 deployment/group_vars/vault.yml   # $ANSIBLE_VAULT;1.1;AES256

# Vault password file exists
ls -la ~/.vault_pass                      # -rw-------

# Server reachable
cd deployment && ansible all -m ping --vault-password-file ~/.vault_pass
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Unable to locate credentials` | Run `aws configure` |
| `ansible: command not found` | `pip3 install ansible` |
| `No module named boto3` | `cd deployment && pip3 install -r requirements.txt` |
| `Permission denied (publickey)` | Check `ansible_ssh_private_key_file` path in hosts.yml |
| `Cannot access vault.yml` | `chmod 600 ~/.vault_pass` |
| Vault shows plaintext | `ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass` |
| `host unreachable` | Confirm `server_host` in vault.yml and `ansible_host` in hosts.yml match |

---

## Next step

Continue to [Chapter 2: Quick Start](QUICKSTART.md) (automated, 10–15 min) or [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) (step-by-step with full explanations).
