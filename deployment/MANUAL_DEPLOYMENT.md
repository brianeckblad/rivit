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

**Complete ALL of these before starting:**

### 1. AWS Resources Created
- [ ] AWS account with admin access
- [ ] S3 bucket created
- [ ] EC2 instance running Ubuntu 22.04
- [ ] Security group allows ports 22, 80, 443

### 2. Local Tools Ready
- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] Python 3.8+ installed
- [ ] Ansible 2.9+ installed
- [ ] SSH access to your server

### 3. Configuration Complete
- [ ] `deployment/group_vars/all.yml` configured
- [ ] `deployment/group_vars/production/vault.yml` created
- [ ] Vault password at `~/.vault_pass`
- [ ] Inventory file has your server IP

**Not ready?** → Complete [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) first

---

## Step 1: AWS Setup

### Create S3 Bucket

```bash
# Choose a globally unique name
aws s3 mb s3://yourname-yourapp-2026 --region us-east-1

# Verify
aws s3 ls | grep yourapp
```

### Launch EC2 Instance

```bash
# Option 1: AWS Console
# 1. EC2 → Launch Instance
# 2. Ubuntu 22.04 LTS
# 3. t3.micro (or t3.nano for cheapest)
# 4. Create key pair, download .pem
# 5. Security group: Allow 22, 80, 443
# 6. Launch

# Option 2: AWS CLI
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --key-name {app_name}-key \
  --security-groups {app_name}-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value={app_name}}]'
```

**Save your instance IP!** You'll need it for the next steps.

### Create IAM Role for EC2 (Optional but Recommended)

```bash
# Create role
aws iam create-role --role-name {app_name}-ec2-role \
  --assume-role-policy-document file://trust-policy.json

# Attach S3 policy
aws iam attach-role-policy --role-name {app_name}-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Attach role to instance
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxx \
  --iam-instance-profile Name={app_name}-ec2-role
```

---

## Step 2: Configure Deployment

### Update Inventory

Edit `deployment/inventories/production/hosts`:

```ini
[production]
your-server-ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/{app_name}-key.pem
```

Replace:
- `your-server-ip` with your EC2 instance IP
- `{app_name}-key.pem` with your key file name

### Configure Application

Edit `deployment/group_vars/all.yml`:

```yaml
app_name: your_app_name          # Your app name (e.g., myapp, inventory_tool, comic_tracker)
app_display_name: "Your App"     # Display name
app_url: "https://github.com/YOUR_USERNAME/your_app_name"  # Change YOUR_USERNAME and app_name
```

### Create Secrets Vault

```bash
cd deployment

# Create vault password (one-time)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create vault
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

Add configuration:

```yaml
---
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app_name.git"
vault_aws_region: "us-east-1"
vault_s3_bucket_name: "yourname-yourapp-2026"
vault_s3_folder: "production"
vault_app_username: "admin"
vault_app_password: "STRONG-PASSWORD-HERE"
```

---

## Step 3: Test Connection

```bash
# Test SSH access
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Test Ansible connection
cd deployment
ansible -i inventories/production all -m ping
# Should return: pong
```

**Connection failed?** Check:
- Security group allows port 22
- Key file permissions: `chmod 400 ~/.ssh/{app_name}-key.pem`
- Correct instance IP in inventory

---

## Step 4: Run Deployment

### Deploy Application

```bash
cd deployment
ansible-playbook -i inventories/production playbooks/setup.yml
```

**This playbook will:**
1. Update system packages
2. Install Python 3.10
3. Create dedicated app user (no SSH access)
4. Create virtual environment
5. Install application dependencies
6. Configure Nginx web server
7. Configure Gunicorn WSGI server
8. Set up systemd service
9. Start application

**Duration:** 10-15 minutes

### Verify Deployment

```bash
# On your local machine
curl http://YOUR_SERVER_IP
# Should show your app

# Check service on server
ssh ubuntu@YOUR_SERVER_IP
sudo systemctl status {app_name}
# Should show: active (running)
```

---

## Step 5: Configure Domain & SSL (Optional)

If you have a custom domain:

### Update DNS

In your DNS provider:
- Create A record: `your-domain.com` → Your server IP
- Wait for DNS propagation (5-30 minutes)

### Install SSL Certificate

```bash
# SSH to server
ssh ubuntu@YOUR_SERVER_IP

# Navigate to scripts
cd /home/ubuntu/{app_name}/deployment/scripts

# Edit SSL setup script
vim ssl-setup.sh
# Line 8: Change DOMAIN="your-domain.com"

# Run SSL setup
./ssl-setup.sh
```

**Done!** Your app now has HTTPS.

---

## Step 6: Final Verification

### Test Application

```bash
# Without SSL
curl http://YOUR_SERVER_IP

# With SSL
curl https://your-domain.com
```

### Check Logs

```bash
ssh ubuntu@YOUR_SERVER_IP

# Application logs
sudo journalctl -u {app_name} -n 50

# Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Test Image Upload

1. Access app in browser
2. Login (credentials from vault)
3. Go to `/add`
4. Upload a test image
5. Check S3 bucket: `aws s3 ls s3://your-bucket-name/`

**Images should appear in S3!**

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

- **ubuntu** (deploy_user): Has SSH, runs git/ansible
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

**Check S3 bucket:**
```bash
aws s3 ls s3://your-bucket-name
```

**Check IAM role (if using):**
```bash
ssh ubuntu@YOUR_SERVER_IP
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Should show role name if attached
```

**Check logs:**
```bash
sudo tail -f /var/log/{app_name}/app.log
# Look for S3-related errors
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

Create `/etc/systemd/system/{app_name}.service`:

```ini
[Unit]
Description={App Name} Flask Application
After=network.target

[Service]
Type=simple
User={app_name}
Group={app_name}
WorkingDirectory=/home/ubuntu/{app_name}
Environment="PATH=/home/ubuntu/.venv/bin"
EnvironmentFile=/home/ubuntu/{app_name}/.env
ExecStart=/home/ubuntu/.venv/bin/gunicorn \
    --bind 127.0.0.1:8000 \
    --workers 4 \
    --timeout 120 \
    "app:create_app('production')"
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable {app_name}
sudo systemctl start {app_name}
```

### 7. Configure Nginx

Create `/etc/nginx/sites-available/{app_name}`:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/{app_name} /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

**Done!** App should be accessible at your server IP.

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
- Manually created AWS infrastructure
- Deployed application step-by-step
- Configured Nginx and Gunicorn
- Set up systemd service
- Optionally added SSL

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

