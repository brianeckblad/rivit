# Manual Deployment Guide - Step by Step

**Version:** 1.0  
**Date:** February 10, 2026  
**Purpose:** Complete manual deployment from zero to production

This guide walks you through every step of deploying the application manually using Ansible playbooks. Follow the steps in order without jumping between documents.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Prepare Local Environment](#step-1-prepare-local-environment)
3. [Step 2: Configure Application Identity](#step-2-configure-application-identity)
4. [Step 3: Create AWS Resources](#step-3-create-aws-resources)
5. [Step 4: Create Ansible Vault](#step-4-create-ansible-vault)
6. [Step 5: Configure Inventory](#step-5-configure-inventory)
7. [Step 6: Initial Server Setup](#step-6-initial-server-setup)
8. [Step 7: Verify Deployment](#step-7-verify-deployment)
9. [Step 8: Post-Deployment Configuration](#step-8-post-deployment-configuration)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Tools You Need (Install First)

```bash
# Python 3.8+ (check version)
python3 --version

# pip (Python package manager)
python3 -m pip --version

# Ansible
pip install ansible

# AWS CLI
pip install awscli boto3

# jq (JSON processor)
brew install jq          # macOS
# OR
sudo apt-get install jq  # Ubuntu/Debian

# Verify installations
ansible --version
aws --version
jq --version
```

### AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Go to https://aws.amazon.com
   - Click "Create an AWS Account"
   - Complete signup

2. **Create IAM User for Deployment**
   - AWS Console → IAM → Users → Add User
   - Username: `deployment-user`
   - Access type: ✅ Programmatic access
   - Permissions: Attach policy `AdministratorAccess`
   - **Save the credentials:**
     - Access Key ID
     - Secret Access Key

3. **Configure AWS CLI**
   ```bash
   aws configure
   # AWS Access Key ID: [paste your key]
   # AWS Secret Access Key: [paste your secret]
   # Default region name: us-east-1
   # Default output format: json
   
   # Test it works
   aws sts get-caller-identity
   # Should show your account ID and user ARN
   ```

### eBay Developer Account (Optional - for eBay features)

1. Go to https://developer.ebay.com
2. Register for developer account
3. Create Production application
4. Note these credentials:
   - Production App ID
   - Production Dev ID
   - Production Cert ID
5. Generate OAuth token using their interface

### GitHub Personal Access Token

1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scope: `repo` only
4. Copy and save the token (starts with `ghp_`)

---

## Step 1: Prepare Local Environment

### 1.1: Clone Your Repository

```bash
# Navigate to where you want the code
cd ~/Development  # or wherever you prefer

# Clone the repository
git clone https://github.com/yourusername/rampe.git
cd rampe

# Verify you're on the main branch
git branch
# Should show: * main
```

### 1.2: Create Vault Password File

```bash
# Create a secure password for Ansible Vault
# This password encrypts your secrets in git
echo "your-secure-vault-password-here" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Verify permissions
ls -la ~/.vault_pass
# Should show: -rw------- (only you can read/write)
```

**Important:** 
- Choose a strong password (20+ characters)
- Save this password in a password manager
- This is different from your AWS credentials

---

## Step 2: Configure Application Identity

### 2.1: Choose Your App Name

Edit `deployment/group_vars/all.yml`:

```bash
nano deployment/group_vars/all.yml
# OR
code deployment/group_vars/all.yml  # if using VS Code
```

Update these lines:

```yaml
# ============================================================================
# Application Identity - CHANGE THESE TO RENAME YOUR APP
# ============================================================================
app_name: rampe                                  # Your app's technical name
app_display_name: "Rampe"                        # Display name
app_url: "https://github.com/yourusername/rampe"  # Your repo URL
```

**Rules for app_name:**
- Lowercase letters only
- No spaces (use underscores if needed)
- Examples: `rampe`, `my_app`, `listkeeper`

### 2.2: Review Other Settings (Optional)

While in `all.yml`, review these settings (defaults are usually fine):

```yaml
gunicorn_workers: 4           # Number of worker processes
log_retention_days: 20        # How long to keep logs
backup_retention_days: 30     # How long to keep backups
```

Save and close the file.

---

## Step 3: Create AWS Resources

### 3.1: Create S3 Bucket

Your S3 bucket name must be **globally unique** across all AWS accounts.

```bash
# Choose a unique name (lowercase, no underscores)
# Example: rampe-prod-12345 or yourcompany-rampe-2026
BUCKET_NAME="rampe-prod-$(date +%s)"  # Adds timestamp for uniqueness

# Create the bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Verify it was created
aws s3 ls | grep $BUCKET_NAME

# Save the bucket name for later
echo "S3_BUCKET_NAME=$BUCKET_NAME" > ~/rampe-deployment-info.txt
echo "Bucket created: $BUCKET_NAME"
```

### 3.2: Create EC2 Key Pair (for SSH access)

```bash
# Create EC2 key pair
aws ec2 create-key-pair \
  --key-name rampe-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/rampe-key.pem

# Set correct permissions
chmod 400 ~/.ssh/rampe-key.pem

# Verify
ls -la ~/.ssh/rampe-key.pem
# Should show: -r-------- (read-only)

echo "EC2_KEY_NAME=rampe-key" >> ~/rampe-deployment-info.txt
```

### 3.3: Create EC2 Instance

```bash
# Get default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
echo "Using VPC: $VPC_ID"

# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name rampe-sg \
  --description "Security group for Rampe application" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

echo "Security Group created: $SG_ID"

# Add SSH rule (from your IP only for security)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32

# Add HTTP rule (from anywhere - for nginx)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Add HTTPS rule (from anywhere - for nginx)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

echo "SECURITY_GROUP_ID=$SG_ID" >> ~/rampe-deployment-info.txt

# Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"

# Launch EC2 instance (t3.nano = cheapest)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.nano \
  --key-name rampe-key \
  --security-group-ids $SG_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=rampe-server}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "EC2 Instance created: $INSTANCE_ID"
echo "INSTANCE_ID=$INSTANCE_ID" >> ~/rampe-deployment-info.txt

# Wait for instance to start
echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance is running!"
echo "Public IP: $PUBLIC_IP"
echo "PUBLIC_IP=$PUBLIC_IP" >> ~/rampe-deployment-info.txt

# Wait for SSH to be ready
echo "Waiting for SSH to be ready (this takes ~60 seconds)..."
sleep 60

# Test SSH connection
ssh -i ~/.ssh/rampe-key.pem -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'SSH connection successful!'"
```

### 3.4: Create IAM Role for EC2 (for S3 and Secrets Manager access)

```bash
# Create trust policy
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name rampe-ec2-role \
  --assume-role-policy-document file:///tmp/ec2-trust-policy.json

# Create policy for S3 and Secrets Manager access
cat > /tmp/rampe-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:rampe/*"
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name rampe-ec2-role \
  --policy-name rampe-access \
  --policy-document file:///tmp/rampe-policy.json

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name rampe-instance-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name rampe-instance-profile \
  --role-name rampe-ec2-role

# Wait for IAM to propagate
echo "Waiting for IAM role to propagate..."
sleep 10

# Attach instance profile to EC2
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=rampe-instance-profile

echo "IAM role attached to EC2 instance"
```

### 3.5: Summary - What You Created

```bash
echo ""
echo "========================================="
echo "AWS Resources Created:"
echo "========================================="
cat ~/rampe-deployment-info.txt
echo "========================================="
echo ""
echo "Save this file! You'll need these values."
```

---

## Step 4: Create Ansible Vault

The vault stores all your sensitive credentials encrypted in git.

### 4.1: Create Vault File

```bash
cd ~/Development/rampe/deployment

# Create the vault file
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

This will open your default editor (nano or vim).

### 4.2: Fill in the Vault Template

Paste this template and fill in your actual values:

```yaml
---
# AWS Configuration
vault_aws_region: "us-east-1"
vault_s3_bucket_name: "YOUR_BUCKET_NAME_FROM_STEP_3"
vault_s3_folder: "production"

# Application Credentials
vault_app_username: "admin"
vault_app_password: "your-secure-admin-password"

# Flask Secret Key (generate with: python3 -c "import secrets; print(secrets.token_hex(32))")
vault_secret_key: "GENERATE_RANDOM_64_CHAR_HEX_STRING"

# eBay Production Credentials (leave empty if not using eBay)
vault_ebay_production_app_id: ""
vault_ebay_production_dev_id: ""
vault_ebay_production_cert_id: ""
vault_ebay_production_token: ""

# eBay Sandbox Credentials (optional)
vault_ebay_sandbox_app_id: ""
vault_ebay_sandbox_dev_id: ""
vault_ebay_sandbox_cert_id: ""
vault_ebay_sandbox_token: ""

# GitHub Deployment
vault_github_token: "YOUR_GITHUB_TOKEN"
vault_github_repo: "yourusername/rampe"
vault_github_branch: "main"

# Application Secret Token (generate with: python3 -c "import secrets; print(secrets.token_hex(16))")
vault_app_secret_token: "GENERATE_RANDOM_32_CHAR_HEX_STRING"

# SNS Topic (optional - for alerts)
vault_sns_topic_arn: ""
```

### 4.3: Generate Secret Keys

Open a new terminal and generate the required secrets:

```bash
# Generate SECRET_KEY
echo "vault_secret_key: \"$(python3 -c 'import secrets; print(secrets.token_hex(32))')\""

# Generate APP_SECRET_TOKEN
echo "vault_app_secret_token: \"$(python3 -c 'import secrets; print(secrets.token_hex(16))')\""
```

Copy these generated values into your vault file.

**Replace these placeholders:**
- `YOUR_BUCKET_NAME_FROM_STEP_3` - The S3 bucket you created
- `YOUR_GITHUB_TOKEN` - Your GitHub personal access token
- `yourusername/rampe` - Your actual GitHub repo
- `your-secure-admin-password` - Choose a strong password
- The generated secret keys

Save and close the editor (Ctrl+X, then Y, then Enter in nano).

### 4.4: Verify Vault

```bash
# View encrypted vault (should show encrypted text)
cat group_vars/production/vault.yml

# Decrypt and view vault (should show your secrets)
ansible-vault view group_vars/production/vault.yml --vault-password-file ~/.vault_pass

# Edit vault later if needed
ansible-vault edit group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

---

## Step 5: Configure Inventory

### 5.1: Create Hosts File

```bash
# Source the deployment info
source ~/rampe-deployment-info.txt

# Create inventory directory
mkdir -p inventories/production

# Create hosts file
cat > inventories/production/hosts.yml << EOF
---
all:
  children:
    production:
      hosts:
        rampe_server:
          ansible_host: $PUBLIC_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/rampe-key.pem
          ansible_python_interpreter: /usr/bin/python3
          
      vars:
        env: production
EOF

echo "Inventory file created at inventories/production/hosts.yml"
```

### 5.2: Test Ansible Connection

```bash
# Test connectivity
ansible production -i inventories/production/hosts.yml -m ping

# Should show:
# rampe_server | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

If this fails, check:
- EC2 instance is running
- Security group allows SSH from your IP
- SSH key has correct permissions (400)

---

## Step 6: Initial Server Setup

Now we deploy the application using Ansible playbooks.

### 6.1: Run Setup Playbook

```bash
cd ~/Development/rampe/deployment

# Run the setup playbook (this takes 5-10 minutes)
ansible-playbook \
  -i inventories/production/hosts.yml \
  playbooks/setup.yml \
  --vault-password-file ~/.vault_pass
```

**What this does:**
1. ✅ Installs system packages (Python, Nginx, Supervisor, etc.)
2. ✅ Creates application directory structure
3. ✅ Clones your GitHub repository
4. ✅ Creates Python virtual environment at `~/.venv`
5. ✅ Installs Python dependencies
6. ✅ Creates `.env` file with configuration
7. ✅ Configures Nginx as reverse proxy
8. ✅ Configures Supervisor to run application
9. ✅ Sets up log rotation
10. ✅ Starts the application

**Watch the output for any errors.**

### 6.2: What To Expect

You'll see output like:

```
PLAY [Setup production server] *************************************************

TASK [Gathering Facts] *********************************************************
ok: [rampe_server]

TASK [Update apt cache] ********************************************************
changed: [rampe_server]

...

PLAY RECAP *********************************************************************
rampe_server : ok=45   changed=38   unreachable=0    failed=0    skipped=2
```

**Success:** `failed=0`
**If failed > 0:** Check the error messages

### 6.3: Upload Secrets to AWS Secrets Manager

```bash
# Create secret in AWS Secrets Manager
ansible-playbook \
  -i inventories/production/hosts.yml \
  playbooks/upload-secrets.yml \
  --vault-password-file ~/.vault_pass \
  --extra-vars "secret_name=rampe/production"
```

This uploads all vault secrets to AWS Secrets Manager so the application can access them securely.

---

## Step 7: Verify Deployment

### 7.1: Check Application Status

```bash
# SSH into the server
source ~/rampe-deployment-info.txt
ssh -i ~/.ssh/rampe-key.pem ubuntu@$PUBLIC_IP

# Check supervisor status
sudo supervisorctl status

# Should show:
# rampe                            RUNNING   pid 12345, uptime 0:05:23

# Check nginx status
sudo systemctl status nginx

# Check application logs
tail -f /var/log/rampe/app.log

# Exit SSH (Ctrl+D)
```

### 7.2: Test Application from Browser

```bash
# Get the public IP again
source ~/rampe-deployment-info.txt
echo "Application URL: http://$PUBLIC_IP"
```

Open that URL in your browser. You should see the application login page.

### 7.3: Test Login

- Username: `admin` (or whatever you set in vault)
- Password: (whatever you set in vault for `vault_app_password`)

If login works, **deployment is successful!** 🎉

---

## Step 8: Post-Deployment Configuration

### 8.1: Set Up CloudFront (Optional but Recommended)

CloudFront provides:
- DDoS protection
- Global CDN
- SSL/TLS certificates
- WAF integration

See `deployment/CLOUDFRONT_SETUP.md` for instructions.

### 8.2: Configure DNS

Point your domain to the EC2 instance:

```
Type: A
Name: rampe.yourdomain.com
Value: YOUR_EC2_PUBLIC_IP
TTL: 300
```

Or point to CloudFront:

```
Type: CNAME
Name: rampe.yourdomain.com
Value: d1234567890abc.cloudfront.net
TTL: 300
```

### 8.3: Set Up SSL Certificate

```bash
# SSH to server
ssh -i ~/.ssh/rampe-key.pem ubuntu@$PUBLIC_IP

# Install certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# Get certificate (replace with your domain)
sudo certbot --nginx -d rampe.yourdomain.com

# Follow the prompts
# Choose: 2 (Redirect HTTP to HTTPS)

# Verify auto-renewal
sudo certbot renew --dry-run
```

### 8.4: Configure Backups

Backups to S3 are automatic via cron job set up by the playbook.

To verify:

```bash
ssh -i ~/.ssh/rampe-key.pem ubuntu@$PUBLIC_IP
crontab -l

# Should show:
# 0 3 * * * cd /home/ubuntu/rampe && ~/.venv/bin/python deployment/files/cleanup_old_backups.py >> /var/log/rampe/cleanup.log 2>&1
```

---

## Troubleshooting

### Application Won't Start

```bash
# Check supervisor logs
sudo supervisorctl tail rampe stderr

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Check application logs
sudo tail -f /var/log/rampe/app.log

# Restart application
sudo supervisorctl restart rampe
```

### Can't SSH to Server

```bash
# Check security group allows your IP
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID

# Update security group to allow your current IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32
```

### Application Returns 502 Bad Gateway

This means Nginx can't reach the application.

```bash
# Check if application is running
sudo supervisorctl status rampe

# If not running, check why
sudo supervisorctl tail rampe stderr

# Check if port 8000 is listening
sudo netstat -tlnp | grep 8000

# Restart application
sudo supervisorctl restart rampe
```

### S3 Upload Fails

```bash
# Check IAM role is attached
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].IamInstanceProfile'

# If no role, attach it
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=rampe-instance-profile

# Reboot instance for IAM role to take effect
aws ec2 reboot-instances --instance-ids $INSTANCE_ID
```

### Ansible Playbook Fails

```bash
# Run with verbose output
ansible-playbook \
  -i inventories/production/hosts.yml \
  playbooks/setup.yml \
  --vault-password-file ~/.vault_pass \
  -vvv  # Very verbose

# Check connectivity
ansible production -i inventories/production/hosts.yml -m ping -vvv
```

### Can't Access Secrets Manager

The EC2 instance must have the IAM role attached. Verify:

```bash
# SSH to server
ssh -i ~/.ssh/rampe-key.pem ubuntu@$PUBLIC_IP

# Try to access secrets
aws secretsmanager get-secret-value --secret-id rampe/production

# If fails, IAM role isn't attached or policy is wrong
```

---

## Next Steps

After successful deployment:

1. **Read OPERATIONS.md** - Learn daily operations (updates, backups, monitoring)
2. **Set up monitoring** - Configure CloudWatch alarms
3. **Enable CloudFront** - Add CDN and DDoS protection
4. **Configure WAF** - Add Web Application Firewall
5. **Set up CI/CD** - Automate deployments with GitHub Actions

---

## Quick Reference

### Important Files

```
deployment/
├── group_vars/
│   ├── all.yml                      # App configuration (edit this)
│   └── production/
│       └── vault.yml                # Secrets (encrypted)
├── inventories/
│   └── production/
│       └── hosts.yml                # Server IP address
└── playbooks/
    ├── setup.yml                    # Initial setup
    ├── update.yml                   # Deploy updates
    └── cleanup-server.yml           # Clean deployment files
```

### Common Commands

```bash
# Deploy code updates
ansible-playbook -i inventories/production/hosts.yml playbooks/update.yml --vault-password-file ~/.vault_pass

# Restart application
ansible production -i inventories/production/hosts.yml -a "sudo supervisorctl restart rampe"

# View logs
ssh -i ~/.ssh/rampe-key.pem ubuntu@$PUBLIC_IP "sudo tail -f /var/log/rampe/app.log"

# Edit vault
ansible-vault edit group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

### AWS Resource Cleanup (if starting over)

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Delete security group (wait for instance to terminate first)
aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID

# Delete S3 bucket (empty it first)
aws s3 rb s3://$BUCKET_NAME --force

# Delete IAM resources
aws iam remove-role-from-instance-profile --instance-profile-name rampe-instance-profile --role-name rampe-ec2-role
aws iam delete-instance-profile --instance-profile-name rampe-instance-profile
aws iam delete-role-policy --role-name rampe-ec2-role --policy-name rampe-access
aws iam delete-role --role-name rampe-ec2-role

# Delete key pair
aws ec2 delete-key-pair --key-name rampe-key
rm ~/.ssh/rampe-key.pem

# Delete secrets
aws secretsmanager delete-secret --secret-id rampe/production --force-delete-without-recovery
```

---

**Congratulations!** You've successfully deployed the application manually. You now understand every component and can troubleshoot issues effectively.

