# Manual Deployment Guide

**Time:** 1-2 hours  
**Skill Level:** Intermediate  
**Method:** Step-by-step with full control

---

## Overview

This guide provides **full manual deployment** with complete control over each step.

**Want it easier?** → See [AUTOMATED_DEPLOYMENT.md](AUTOMATED_DEPLOYMENT.md)

---

## Prerequisites

**⚠️ IMPORTANT: This guide assumes nothing is configured. Follow these steps completely.**

### Before You Begin

If you have **never used AWS, Git, or Ansible before**, start here:

**Complete setup guide:** → [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)

This checklist walks through:
- Creating AWS account from scratch
- Installing and configuring AWS CLI
- Installing Python and Ansible
- Installing and configuring Git
- Setting up GitHub authentication
- Creating IAM users and access keys
- Verifying everything works

**Already have everything installed and configured?** Continue below.

---

### Quick Verification

Run these commands to verify you're ready:

```bash
# AWS CLI configured?
aws sts get-caller-identity
# Should show your AWS account details

# Python installed?
python3 --version
# Should show: Python 3.8 or higher

# Ansible installed?
ansible --version
# Should show: ansible [core 2.9+]

# Git configured?
git config --list | grep user
# Should show: user.name and user.email

# Deployment requirements installed?
pip3 list | grep -E "ansible|boto3|awscli"
# Should show all three packages
```

**All commands work?** ✅ Continue to deployment steps below.

**Any command fails?** ❌ Go to [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)

**Missing deployment requirements?** Install them:
```bash
cd your_app_name
pip3 install -r deployment/requirements.txt
```

**Managing multiple AWS accounts or regions?**
- See [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md) for setting up named profiles
- Use with ansible: `AWS_PROFILE=myapp-production ansible-playbook ...`

---

### Prerequisites

**You'll need:**

**1. AWS Resources (Created in Step 1)**
- AWS account with admin access
- SSH key pair
- Security group
- S3 bucket
- EC2 instance running Ubuntu 22.04

**2. Local Tools**
- AWS CLI configured
- Python 3.8+ installed
- Ansible 2.9+ installed
- Deployment requirements installed (`pip3 install -r deployment/requirements.txt`)
- Git installed and configured

**3. Configuration Files**
- `deployment/group_vars/all.yml` configured (app_name set)
- `deployment/group_vars/production/vault.yml` created
- Vault password at `~/.vault_pass`
- Inventory file with your server IP

**Not ready?** → [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)

---

## Step 0: Clone Repository

**⚠️ DO THIS FIRST - Everything else requires these files!**

**On your local machine:**

```bash
# 1. Choose a directory for your project
cd ~  # Or cd ~/Projects, or wherever you keep code

# 2. Clone your repository
git clone https://github.com/YOUR_USERNAME/your_app_name.git
# Replace YOUR_USERNAME with your GitHub username
# Replace your_app_name with your repository name

# 3. Enter the repository
cd your_app_name

# 4. Verify you have the deployment files
ls deployment/
# Should show: group_vars/, playbooks/, scripts/, templates/, etc.

# 5. Install deployment requirements
pip3 install -r deployment/requirements.txt
# This installs: ansible, boto3, awscli, and other tools

# 6. Verify installation
pip3 list | grep -E "ansible|boto3|awscli"
# Should show all three packages with version numbers
```

**✅ Checkpoint:** You should now be in the repository directory with all files present.

**From now on, all commands assume you're in this directory!**

---

## Step 1: Provision AWS Infrastructure

**⚠️ On your LOCAL machine, in the repository directory**

### Option 1: Use Ansible Playbook (Recommended)

```bash
cd deployment

# Create S3 bucket
aws s3 mb s3://yourname-yourapp-2026 --region us-east-2

# Provision EC2 instance (creates security group, SSH key, EC2)
ansible-playbook playbooks/provision-ec2.yml

# Instance info saved to: deployment/instance-info.txt
# SSH key saved to: ~/.ssh/{app_name}-key.pem
```

**Output shows:**
- Instance ID
- Public IP address
- SSH command
- Next steps

### Option 2: Use AWS CLI/Console Manually

If you prefer manual control:

**Create S3 Bucket:**
```bash
aws s3 mb s3://yourname-yourapp-2026 --region us-east-2
```

**Create SSH Key Pair:**

**Option 1: AWS Console**
1. Go to EC2 → Network & Security → Key Pairs
2. Click **Create key pair**
3. Name: `{app_name}-key`
4. Type: RSA
5. Format: .pem
6. Click **Create key pair** (downloads automatically)
7. Move to SSH directory:
   ```bash
   mv ~/Downloads/{app_name}-key.pem ~/.ssh/
   chmod 400 ~/.ssh/{app_name}-key.pem
   ```

**Option 2: AWS CLI**
```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name {app_name}-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/{app_name}-key.pem

# Set correct permissions
chmod 400 ~/.ssh/{app_name}-key.pem
```

### Create Security Group

**Option 1: AWS Console**
1. Go to EC2 → Network & Security → Security Groups
2. Click **Create security group**
3. Name: `{app_name}-sg`
4. Description: "Security group for {app_name}"
5. Add inbound rules:
   - SSH: Port 22, Source: Your IP (or 0.0.0.0/0 for anywhere)
   - HTTP: Port 80, Source: 0.0.0.0/0
   - HTTPS: Port 443, Source: 0.0.0.0/0
6. Click **Create security group**

**Option 2: AWS CLI**
```bash
# Create security group
aws ec2 create-security-group \
  --group-name {app_name}-sg \
  --description "Security group for {app_name}"

# Add SSH rule (replace YOUR_IP with your IP address)
aws ec2 authorize-security-group-ingress \
  --group-name {app_name}-sg \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32

# Add HTTP rule
aws ec2 authorize-security-group-ingress \
  --group-name {app_name}-sg \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Add HTTPS rule
aws ec2 authorize-security-group-ingress \
  --group-name {app_name}-sg \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

**Tip:** Get your current IP: `curl ifconfig.me`

### Launch EC2 Instance

**Option 1: AWS Console**
1. Go to EC2 → Instances
2. Click **Launch Instance**
3. **Name:** `{app_name}`
4. **AMI:** Ubuntu Server 22.04 LTS
5. **Instance type:** t3.micro (or t3.nano for cheapest)
6. **Key pair:** Select `{app_name}-key` (created above)
7. **Network settings:** 
   - Click "Select existing security group"
   - Select `{app_name}-sg` (created above)
8. **Storage:** 8 GB (default is fine)
9. Click **Launch instance**
10. Wait 2-3 minutes for instance to start

**Option 2: AWS CLI**
```bash
# Get Ubuntu 22.04 AMI ID for us-east-2
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name {app_name}-key \
  --security-groups {app_name}-sg \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value={app_name}}]"
```

**Get your instance IP:**
```bash
# Using AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values={app_name}" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text

# Or check AWS Console: EC2 → Instances → Select your instance → Copy "Public IPv4 address"
```

**Save your instance IP!** You'll need it for the next steps.


---

## Step 2: Configure Deployment

**⚠️ On your LOCAL machine, in the repository directory**

### Update Inventory File

**File to edit:** `deployment/inventories/production/hosts.yml` ← Note: .yml extension!

```bash
# Open the file
vim deployment/inventories/production/hosts.yml
# Or use your preferred editor: nano, code, etc.
```

**Find this line:**
```yaml
ansible_host: localhost
```

**Replace with your EC2 instance IP:**
```yaml
ansible_host: 3.145.123.45  # Your actual EC2 IP from Step 1
```

**Complete example:**
```yaml
---
all:
  children:
    production:
      hosts:
        prod:
          ansible_host: 3.145.123.45  # ← YOUR EC2 IP HERE
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem  # ← YOUR KEY NAME

      vars:
        env_name: production
        ansible_python_interpreter: /usr/bin/python3
```

**Save and close** the file.

### Configure Application Settings

**File to edit:** `deployment/group_vars/all.yml`

**File to edit:** `deployment/group_vars/all.yml`

```bash
# Open the file
vim deployment/group_vars/all.yml
```

**Find the USER CONFIGURATION section at the top:**

```yaml
# Change these two lines:
app_name: CHANGEME                    # ← Your app name: myapp, comictracker, etc.
app_display_name: "CHANGE ME"         # ← Display name: "My App", "Comic Tracker"
```

**Example:**
```yaml
app_name: myapp
app_display_name: "My Application"
```

**Save and close** the file. Everything else in this file is auto-configured!

### Create Secrets Vault

**⚠️ Still on your LOCAL machine**

The vault stores sensitive information (passwords, AWS details, GitHub URL).

**Step 1: Create vault password file**

```bash
# Create password file in your home directory
echo "your-super-secret-vault-password" > ~/.vault_pass

# Replace "your-super-secret-vault-password" with a strong password
# Example: echo "MyV4ultP@ssw0rd2026!" > ~/.vault_pass

# Set secure permissions
chmod 600 ~/.vault_pass

# Verify
ls -la ~/.vault_pass
# Should show: -rw------- (only you can read/write)
```

**Step 2: Create the vault file**

```bash
# Make sure you're in the repository directory
cd deployment

# Create encrypted vault file
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

**This opens an editor. Add this content:**

```yaml
---
# Git Repository (REQUIRED)
vault_git_repo: "https://github.com/YOUR_GITHUB_USERNAME/your_repository_name.git"
# ↑ Replace YOUR_GITHUB_USERNAME with your actual GitHub username
# ↑ Replace your_repository_name with your actual repository name
# Example: "https://github.com/john/myapp.git"

# AWS Configuration (REQUIRED)
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"  # ← Your S3 bucket from Step 1
vault_s3_folder: "production"

# Application Credentials (REQUIRED)
# These are for YOUR app's admin login - make them up!
vault_app_username: "admin"  # ← Can be anything you want
vault_app_password: "MAKE-UP-A-STRONG-PASSWORD"  # ← CREATE a strong password

# eBay API Credentials (OPTIONAL - only if using eBay features)
# Leave as empty strings "" if you don't have eBay API access
vault_ebay_app_id: ""
vault_ebay_cert_id: ""
vault_ebay_dev_id: ""
vault_ebay_token: ""

# SNS Topic (OPTIONAL - for alerts)
vault_sns_topic_arn: ""  # Leave empty for now
```

**Important notes:**
- **vault_git_repo:** Your repository URL (get from GitHub repo page)
- **vault_s3_bucket_name:** The S3 bucket you created in Step 1
- **vault_app_username/password:** YOU make these up! This is for logging into YOUR app
- **eBay fields:** Leave as `""` if you're not using eBay API features
- **Make STRONG passwords!** Not "password123"

**Save and close** the editor (in vim: press Esc, type `:wq`, press Enter).

**Step 3: Verify vault was created**

```bash
# Check file exists
ls -la group_vars/production/vault.yml
# Should show the file

# Test you can read it (should prompt for password)
ansible-vault view group_vars/production/vault.yml --vault-password-file ~/.vault_pass
# Should show your configuration

# Go back to repository root
cd ..
```

**✅ Checkpoint:** You now have:
- Repository cloned ✓
- Inventory configured with your server IP ✓
- Application name set ✓
- Vault created with secrets ✓

---

## Step 3: Test Connection

**⚠️ On your LOCAL machine**

Before deploying, verify you can connect to your server.

### Test SSH Access

```bash
# Replace YOUR_SERVER_IP with your EC2 instance IP from Step 1
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Example: ssh -i ~/.ssh/myapp-key.pem ubuntu@3.145.123.45

# You should see Ubuntu welcome message
# If successful, type: exit
```

**SSH Connection Issues?**
- **Permission denied:** Check key permissions: `chmod 400 ~/.ssh/{app_name}-key.pem`
- **Connection timeout:** Check security group allows port 22
- **Host key verification:** Type `yes` when prompted first time

### Test Ansible Connection

```bash
# Make sure you're in the repository directory
cd ~/your_app_name  # Or wherever you cloned the repo

# Test Ansible can connect
ansible -i deployment/inventories/production all -m ping

# Should see:
# prod | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

**Ansible Connection Failed?**
- **No hosts matched:** Check inventory file has correct IP
- **Permission denied:** Check key path in inventory file
- **unreachable:** Check server is running: `aws ec2 describe-instances --instance-ids i-xxxxx`

**✅ Checkpoint:** If ping returns "pong", you're ready to deploy!

---

## Step 4: Run Deployment

**⚠️ On your LOCAL machine, from the repository directory**

### Deploy Application

```bash
# Make sure you're in the repository root (not deployment/ subdirectory)
cd ~/your_app_name  # Adjust to your actual path

# Run the deployment playbook
ansible-playbook -i deployment/inventories/production deployment/playbooks/setup.yml

# This will take 10-15 minutes
# You'll see lots of output - this is normal!
# Look for "PLAY RECAP" at the end
```

**Using AWS Profiles?** (If managing multiple AWS accounts)
```bash
# Deploy with specific AWS profile
AWS_PROFILE=myapp-production ansible-playbook -i deployment/inventories/production deployment/playbooks/setup.yml

# Or set for entire session
export AWS_PROFILE=myapp-production
ansible-playbook -i deployment/inventories/production deployment/playbooks/setup.yml
```

**See:** [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md) for profile setup details.

### What The Playbook Does

**This will:**
1. ✅ Update system packages on server
2. ✅ Install Python 3.10 and dependencies
3. ✅ Create dedicated app user (no SSH access)
4. ✅ Clone your GitHub repository to server
5. ✅ Create Python virtual environment
6. ✅ Install application dependencies (pip install -r requirements.txt)
7. ✅ Configure Nginx web server
8. ✅ Configure Gunicorn WSGI server
9. ✅ Set up systemd service
10. ✅ Apply security hardening
11. ✅ Start application

**Duration:** 10-15 minutes

**Expected output at end:**
```
PLAY RECAP *************************************************
prod     : ok=45   changed=32   unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
```

**✅ Success** if `failed=0` and `unreachable=0`

**❌ Failed?** See [Troubleshooting](#troubleshooting) section below

### Verify Deployment

**On your LOCAL machine:**

```bash
# Test the application
curl http://YOUR_SERVER_IP
# Should return HTML (your app's homepage)

# Example: curl http://3.145.123.45
```

**Check service on server:**

```bash
# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check application status
sudo systemctl status {app_name}
# Should show: "active (running)" in green

# Check nginx status  
sudo systemctl status nginx
# Should show: "active (running)" in green

# Exit server
exit
```

**✅ Checkpoint:** Application is now running!

---

## Step 5: Configure Domain & SSL

**⚠️ Only if you have a custom domain name**

If you don't have a domain, you can access your app via IP address and skip to [Step 6](#step-6-final-verification).

### Update DNS Records

**In your DNS provider (Namecheap, GoDaddy, Cloudflare, etc.):**

1. Log into your DNS provider
2. Find your domain's DNS settings
3. Create an **A record:**
   - **Name/Host:** `@` (or blank, or `your-domain.com`)
   - **Value/Points to:** Your EC2 instance IP
   - **TTL:** 300 (5 minutes) or Auto
4. Save changes
5. Wait 5-30 minutes for DNS propagation

**Test DNS propagation:**
```bash
# On your local machine
nslookup your-domain.com
# Should show your server IP

# Or use:
dig your-domain.com +short
# Should show your server IP
```

**Wait until DNS propagation completes before continuing!**

### Install SSL Certificate (Let's Encrypt)

**⚠️ This section runs ON THE SERVER**

```bash
# 1. SSH to your server (FROM YOUR LOCAL MACHINE)
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# 2. Navigate to scripts directory (NOW ON THE SERVER)
cd /home/ubuntu/{app_name}/deployment/scripts

# 3. Edit the SSL setup script
nano ssl-setup.sh
# Or use: vim ssl-setup.sh

# 4. Find this line (around line 8):
# DOMAIN="your-domain.com"

# 5. Change to your actual domain:
# DOMAIN="myactualwebsite.com"

# 6. Save and exit:
# nano: Press Ctrl+X, then Y, then Enter
# vim: Press Esc, type :wq, press Enter

# 7. Run the SSL setup script
sudo ./ssl-setup.sh

# 8. Follow the prompts:
# - Enter your email address (for certificate expiration notices)
# - Agree to terms of service: Y
# - Share email with EFF (optional): Y or N

# 9. Script will automatically:
# - Install certbot
# - Request SSL certificate from Let's Encrypt
# - Configure nginx for HTTPS
# - Set up automatic renewal
# - Restart nginx

# 10. Exit back to your local machine
exit
```

**✅ Done!** Your app now has HTTPS.

**Test SSL:**
```bash
# On your local machine
curl https://your-domain.com
# Should show your app over HTTPS

# Check in browser:
# https://your-domain.com
# Should show lock icon 🔒
```

---

## Step 6: Final Verification

### Test Application

```bash
# Without SSL (using IP)
curl http://YOUR_SERVER_IP

# With SSL (using domain)
curl https://your-domain.com

# Or open in browser
# http://YOUR_SERVER_IP or https://your-domain.com
```

### Check Logs

```bash
# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Application logs
sudo journalctl -u {app_name} -n 50

# Nginx access logs
sudo tail -f /var/log/nginx/{app_name}_access.log

# Nginx error logs
sudo tail -f /var/log/nginx/{app_name}_error.log

# Exit server
exit
```

**✅ Deployment complete!** Your application is now running.

---

## What Was Deployed?

### Server Components

```
/home/ubuntu/{app_name}/              # Application code (owned by ubuntu)
/home/ubuntu/.venv/                   # Python virtual environment
/var/log/{app_name}/                  # Logs (owned by {app_name} user)
/home/ubuntu/{app_name}/instance/     # Data files (owned by {app_name} user)
/etc/nginx/sites-available/{app_name} # Nginx config
/etc/systemd/system/{app_name}.service # Systemd service
```

### Users Created

- **ubuntu** (admin_user): Has SSH, runs git/ansible
- **{app_name}** (app_user): No SSH, no shell, runs application only

### Services Running

```bash
# Check all services
sudo systemctl status {app_name}
sudo systemctl status nginx
```

### Security Features

- ✅ Dedicated app user (no SSH access)
- ✅ 20+ systemd security hardening features
- ✅ Firewall (UFW) configured
- ✅ Read-only code directory
- ✅ Limited write access (logs and data only)

**Details:** → [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## Common Tasks

### Update Application Code

```bash
cd deployment
ansible-playbook -i inventories/production playbooks/update.yml
```

### Restart Application

```bash
# Using Ansible
ansible -i inventories/production all -a "sudo systemctl restart {app_name}"

# Or SSH to server
ssh ubuntu@YOUR_SERVER_IP
sudo systemctl restart {app_name}
```

### View Logs

```bash
ssh ubuntu@YOUR_SERVER_IP
sudo journalctl -u {app_name} -f  # Live logs
```

### Add Users

See [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)

---

## Troubleshooting

### Ansible Playbook Failed

**Check connection:**
```bash
ansible -i inventories/production all -m ping
```

**Check syntax:**
```bash
ansible-playbook --syntax-check -i inventories/production playbooks/setup.yml
```

**Re-run playbook:**
```bash
ansible-playbook -i inventories/production playbooks/setup.yml -v
# Use -v, -vv, or -vvv for more verbosity
```

### Service Won't Start

```bash
# SSH to server
ssh ubuntu@YOUR_SERVER_IP

# Check service status
sudo systemctl status {app_name}

# View detailed logs
sudo journalctl -u {app_name} -n 100 --no-pager

# Common fixes:
sudo chown -R {app_name}:{app_name} /var/log/{app_name}
sudo chown -R {app_name}:{app_name} /home/ubuntu/{app_name}/instance
sudo systemctl daemon-reload
sudo systemctl restart {app_name}
```

### Can't Access Website

**Check Nginx:**
```bash
sudo systemctl status nginx
sudo nginx -t  # Test config
```

**Check firewall:**
```bash
sudo ufw status
# Should show: 80/tcp ALLOW, 443/tcp ALLOW
```

**Check security group:**
- AWS Console → EC2 → Security Groups
- Inbound rules should allow ports 80, 443

### Images Not Uploading

**Check S3 bucket exists:**
```bash
aws s3 ls s3://your-bucket-name
```

**Check application logs for S3 errors:**
```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo tail -f /var/log/{app_name}/app.log | grep -i s3
# Look for S3-related errors
exit
```

**Check S3 bucket configuration:**
```bash
# Verify bucket region matches your configuration
aws s3api get-bucket-location --bucket your-bucket-name
# Should show: us-east-2 (or your configured region)
```

**More help:** → [OPERATIONS.md#troubleshooting](OPERATIONS.md#troubleshooting)

---

## Manual Server Setup (Alternative)

If you prefer setting up the server manually instead of Ansible:

### 1. Update System

```bash
ssh ubuntu@YOUR_SERVER_IP

sudo apt update && sudo apt upgrade -y
sudo apt install python3-pip python3-venv nginx -y
```

### 2. Clone Repository

```bash
cd /home/ubuntu
git clone https://github.com/YOUR_USERNAME/your_app_name.git
cd your_app_name
```

### 3. Create Virtual Environment

```bash
python3 -m venv ~/.venv
source ~/.venv/bin/activate
pip install -r requirements.txt
```

### 4. Configure Environment

```bash
cp .env.example .env
vim .env
# Add your AWS credentials, S3 bucket, etc.
```

### 5. Create App User

```bash
sudo useradd -r -s /usr/sbin/nologin {app_name}
sudo mkdir -p /var/log/{app_name}
sudo chown {app_name}:{app_name} /var/log/{app_name}
sudo chown {app_name}:{app_name} /home/ubuntu/{app_name}/instance
```

### 6. Configure Systemd

**Generate the service file with proper variables:**

```bash
# On your LOCAL machine, in the repository
cd deployment/scripts
./manual-generate-systemd.sh

# This creates: deployment/{app_name}.service
# with all variables properly substituted
```

**Copy to server and install:**

```bash
# Copy to server (replace YOUR_SERVER_IP)
scp -i ~/.ssh/{app_name}-key.pem ../myapp.service ubuntu@YOUR_SERVER_IP:/tmp/

# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Install service file
sudo mv /tmp/{app_name}.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable {app_name}
sudo systemctl start {app_name}

# Verify it's running
sudo systemctl status {app_name}

# Exit server
exit
```

### 7. Configure Nginx

**Generate the nginx configuration with proper variables:**

```bash
# On your LOCAL machine, in the repository
cd deployment/scripts
./manual-generate-nginx.sh

# Script will ask for your domain name
# Press Enter to use IP-based access (no domain)
# Or enter your domain: example.com

# This creates: deployment/{app_name}-nginx.conf
# with all variables properly substituted
```

**Copy to server and install:**

```bash
# Copy to server (replace YOUR_SERVER_IP)
scp -i ~/.ssh/{app_name}-key.pem ../{app_name}-nginx.conf ubuntu@YOUR_SERVER_IP:/tmp/

# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Install nginx config
sudo mv /tmp/{app_name}-nginx.conf /etc/nginx/sites-available/{app_name}
sudo ln -s /etc/nginx/sites-available/{app_name} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Verify it's running
sudo systemctl status nginx

# Exit server
exit
```

**Done!** App should be accessible at your server IP or domain.

---

## Next Steps

**Learn operations:**
- Daily tasks: [OPERATIONS.md](OPERATIONS.md)
- Add users: [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)
- Manage secrets: [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)
- Security details: [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## Summary

✅ **What you did:**
- Created AWS infrastructure (S3, EC2, Security Group, SSH Key)
- Deployed application step-by-step
- Configured Nginx and Gunicorn
- Set up systemd service
- Added SSL (if using custom domain)

✅ **What you have:**
- Full control over every component
- Understanding of entire stack
- Production-ready deployment
- Secure configuration

✅ **What's next:**
- Learn [OPERATIONS.md](OPERATIONS.md) for daily management
- Add users with [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)
- Understand security with [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

<div align="center">

**Deployment complete!** 🎉  
[← Back to README](README.md) | [Operations Guide →](OPERATIONS.md)

</div>

