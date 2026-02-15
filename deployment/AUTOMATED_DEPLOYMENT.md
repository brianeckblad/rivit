# Automated Deployment Guide

**Time:** 15-20 minutes  
**Skill Level:** Beginner  
**Method:** One command does everything

---

## Overview

This guide walks you through **automated deployment** where one command creates:
- ✅ AWS EC2 instance with security groups
- ✅ S3 bucket for image storage
- ✅ IAM roles (no credentials on server)
- ✅ Complete app deployment with Nginx + Gunicorn
- ✅ SSL setup (if you have a domain)

**Prefer manual control?** → See [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)

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

**Before starting, you need:**

### 1. AWS Account
- AWS account with admin access
- Credit card registered (free tier available)

### 2. Local Tools Installed

**Quick check:**
```bash
# Check if you have these:
aws sts get-caller-identity    # AWS CLI configured
python3 --version              # Python 3.8+
ansible --version              # Ansible 2.9+
git --version                  # Git installed
pip3 list | grep boto3         # Deployment requirements
```

**All commands work?** ✅ You're ready!

**Any command fails?** ❌ See [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) for detailed installation instructions.

**Missing boto3/deployment tools?** Install them:
```bash
cd your_app_name
pip3 install -r deployment/requirements.txt
```

**Managing multiple AWS accounts or regions?** 
- See [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md) for setting up named profiles
- Deploy with: `AWS_PROFILE=myapp-production ./scripts/infra-complete-setup.sh`

### 3. GitHub Repository
- Your code pushed to GitHub
- Repository URL ready

**Not ready?** → Complete [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md) first

---

## Deployment Steps

### Step 1: Configure Application

Edit `deployment/group_vars/all.yml`:

```yaml
# Required: Update these
app_name: your_app_name                      # Your app name (e.g., myapp, inventory_tool, comic_tracker)
app_display_name: "Your App Name"            # Display name  
```

**Note:** Git repository URL is configured in vault.yml (step 2)

### Step 2: Create Secrets Vault

```bash
cd deployment

# Create vault password file (one-time)
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create encrypted vault
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

Add this content to the vault:

```yaml
---
# Git Repository
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app_name.git"  # Your repo

# AWS
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"  # Must be globally unique!
vault_s3_folder: "production"

# App Credentials
vault_app_username: "admin"
vault_app_password: "CHANGE-THIS-PASSWORD"  # Strong password!

# Optional: eBay (leave blank if not using)
vault_ebay_app_id: ""
vault_ebay_cert_id: ""
vault_ebay_dev_id: ""
vault_ebay_token: ""

# Optional: SNS alerts
vault_sns_topic_arn: ""
```

**Save and exit** - Type :wq in vim

### Step 3: Verify Configuration

```bash
# Check app_name was set
grep "app_name:" deployment/group_vars/all.yml
# Should show your app name, not "CHANGEME"

# Test vault can be read
ansible-vault view group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# Should show YOUR repository URL
```
```

### Step 4: Run Automated Deployment

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

**Using AWS Profiles?** (Multiple accounts or regions)
```bash
# Deploy to production account
AWS_PROFILE=myapp-production ./scripts/infra-complete-setup.sh

# Or set for session
export AWS_PROFILE=myapp-production
./scripts/infra-complete-setup.sh
```

**See:** [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md) for profile setup details.

**This script will:**
1. Create EC2 instance (t3.micro)
2. Configure security groups
3. Create S3 bucket
4. Set up IAM roles
5. Install Python, Nginx, Gunicorn
6. Deploy your application
7. Start the service

**Duration:** 15-20 minutes

**Output:** Script shows your server IP and application URL when complete.

### Step 5: Verify Deployment

```bash
# Check your server IP from script output
curl http://YOUR_SERVER_IP

# Or if you configured a domain
curl https://your-domain.com
```

**Should see:** Your application login page

---

## SSL Setup (If Using Custom Domain)

**⚠️ Skip this if accessing via IP address only**

If you have a custom domain:

### Step 1: Point DNS to Server

In your DNS provider (Namecheap, GoDaddy, Cloudflare, etc.):
- Create A record: `your-domain.com` → Your server IP
- Wait 5-30 minutes for DNS propagation

### Step 2: Run SSL Setup

```bash
# SSH to your server
ssh ubuntu@YOUR_SERVER_IP

# Navigate to scripts
cd /home/ubuntu/{app_name}/deployment/scripts

# Edit SSL script
nano ssl-setup.sh
# Change line 8: DOMAIN="your-domain.com"
# Save: Ctrl+X, Y, Enter

# Run SSL setup
sudo ./ssl-setup.sh
```

**Done!** Your app now has HTTPS with Let's Encrypt certificate.

---

## What Was Created?

### AWS Resources

| Resource | Description | Cost |
|----------|-------------|------|
| EC2 Instance (t3.micro) | Web server | $7.50/mo (or free tier) |
| S3 Bucket | Image storage | ~$0.50/mo |
| Security Group | Firewall rules | Free |
| IAM Role | Server permissions | Free |

**Total monthly cost:** ~$10-15/month (or ~$2/month on free tier)

### On Your Server

```
/home/ubuntu/{app_name}/          # Your application code
/home/ubuntu/.venv/               # Python virtual environment
/var/log/{app_name}/              # Application logs
/etc/nginx/                       # Nginx configuration
/etc/systemd/system/{app_name}.service  # Systemd service
```

### Security Features

- ✅ Dedicated app user (no SSH access)
- ✅ Systemd hardening (20+ security features)
- ✅ Firewall configured (UFW)
- ✅ IAM roles (no AWS credentials on disk)
- ✅ Encrypted secrets (Ansible Vault)

---

## Next Steps

### 1. Test Your Application

```bash
# Access in browser
http://YOUR_SERVER_IP

# Login with credentials from vault
Username: admin
Password: (whatever you set in vault)
```

### 2. Add Comics

1. Go to `/add`
2. Fill in comic details
3. Upload images
4. Save

Images automatically upload to S3!

### 3. Learn Operations

**Common tasks:**
- Update code: See [OPERATIONS.md](OPERATIONS.md#updating-application)
- View logs: See [OPERATIONS.md](OPERATIONS.md#viewing-logs)
- Add users: See [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)
- Troubleshoot: See [OPERATIONS.md#troubleshooting](OPERATIONS.md#troubleshooting)

---

## Troubleshooting

### Deployment Script Failed

**Check AWS credentials:**
```bash
aws sts get-caller-identity
# Should show your AWS account details
```

**Check ansible:**
```bash
ansible --version
# Should be 2.9+
```

**Re-run script:**
```bash
cd deployment
./scripts/infra-complete-setup.sh
```

Script is idempotent - safe to run multiple times.

### Can't Access Application

**Check EC2 instance:**
```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values={app_name}" --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]'
```

**Check security group:**
- Should allow inbound on ports 22, 80, 443
- Check in AWS Console → EC2 → Security Groups

**Check service on server:**
```bash
ssh ubuntu@YOUR_SERVER_IP
sudo systemctl status {app_name}
```

### Images Not Uploading

**Check S3 bucket:**
```bash
aws s3 ls s3://your-bucket-name
# Should work
```

**Check IAM role on server:**
```bash
ssh ubuntu@YOUR_SERVER_IP
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Should show role name
```

**More help:** → [OPERATIONS.md#troubleshooting](OPERATIONS.md#troubleshooting)

---

## Prerequisites Setup

### Install AWS CLI

**macOS:**
```bash
brew install awscli
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install awscli
```

**Configure:**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-2), Format (json)
```

**Don't have AWS keys?** Create IAM user:
1. AWS Console → IAM → Users → Create User
2. Name: `{app_name}-deploy` (e.g., `myapp-deploy`)
3. Attach policy: `AdministratorAccess`
4. Create Access Key → Save credentials

### Install Python & Ansible

**macOS:**
```bash
brew install python3 ansible
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install python3 python3-pip ansible
```

**Verify:**
```bash
python3 --version  # Should be 3.8+
ansible --version  # Should be 2.9+
```

---

## Cost Breakdown

**AWS Free Tier (First 12 Months):**
- EC2 t3.micro: 750 hours/month free
- S3: 5GB free
- **Estimated cost: $1-2/month**

**After Free Tier:**
- EC2 t3.micro: $7.50/month
- S3 storage: $0.50/month (20GB)
- Data transfer: $1-2/month
- **Estimated cost: $10-15/month**

**Optimize costs:**
- Use reserved instances (1-year commitment = 40% savings)
- Enable S3 lifecycle policies
- Monitor usage with AWS Cost Explorer

---

## Support

**Need help?**

1. Check [Troubleshooting](#troubleshooting) above
2. Review [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)
3. See [OPERATIONS.md](OPERATIONS.md) for post-deployment help
4. Create [GitHub Issue](../../issues)

---

## Next Steps

- **Daily Operations:** [OPERATIONS.md](OPERATIONS.md) - Updates, backups, monitoring
- **Multi-User Setup:** [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md) - Add users if needed
- **Security Details:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md) - Understand security features

---

<div align="center">

**Deployment complete!** 🎉  
[← Back to README](README.md) | [Operations Guide →](OPERATIONS.md)

</div>

