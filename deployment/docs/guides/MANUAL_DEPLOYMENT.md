# Manual Deployment Guide

**Learn how to deploy by doing - step-by-step with full explanations**

This guide walks you through each deployment step with three options:
1. **Playbook** - Automated with Ansible (fastest)
2. **CLI** - Step-by-step with AWS CLI commands
3. **Console** - Point & click in AWS web console

Learn something new with each step!

---

## About Secrets & Vault

**Your vault.yml file is encrypted and safe.** Ansible automatically:
- ✅ Reads your encrypted vault.yml
- ✅ Uses ~/.vault_pass to decrypt it
- ✅ No manual vault password entry needed
- ✅ Works with all playbook commands below

**If a playbook asks for vault password:** Make sure ~/.vault_pass exists with proper permissions (600).

---

## Prerequisites

✅ **Have you done this yet?** Complete before starting deployment:

→ [PREREQUISITES.md](PREREQUISITES.md) - AWS account, CLI setup, local tools

**Not done?** Do that first. Come back here when you see:
```bash
$ aws sts get-caller-identity
{
    "Account": "123456789012",
    "UserId": "...",
    "Arn": "arn:aws:iam::123456789012:user/..."
}
```

---

## Load Configuration Variables

**Before running CLI commands, load your variables into shell:**

All CLI commands in this guide use `$app_name`, `$aws_region`, etc. These come from your config files.

### Setup (One Time)

```bash
cd deployment

# Load variables into current shell session
source scripts/load-vars.sh
```

**You should see:**
```
✅ Variables loaded successfully

Available variables (non-vault):
  app_name=rampe
  app_display_name=Rampe Application
  aws_region=us-east-2
  admin_user=ubuntu
  server_name=rampe.ipix.io
```

### Use Variables in Commands

Now all CLI commands can use the variables:

```bash
# Variables are available
echo $app_name
echo $aws_region
echo $admin_user

# Use in AWS CLI commands
aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
aws ec2 describe-security-groups --group-names ${app_name}-sg
```

### Variables from Vault

**Note:** Vault variables won't load into shell (they're encrypted).

For commands that need vault variables (like API keys), use Ansible playbooks instead:
```bash
# Playbooks automatically decrypt vault
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass
```

---

## Deployment Steps

### Overview: What Gets Deployed

```
Your Local Machine
       ↓
 [Infrastructure Layer] ← Steps 1-5 below
       ↓
┌─────────────────────────┐
│   AWS Region (us-east-2) │
├─────────────────────────┤
│                         │
│  EC2 Instance (Ubuntu)  │
│  - Nginx (web server)   │
│  - Gunicorn (app)       │
│  - Systemd (auto-start) │
│                         │
│  ↓ Stores data to:      │
│  S3 Bucket (storage)    │
│                         │
│  ↓ Uses role:           │
│  IAM Role (permissions) │
│                         │
└─────────────────────────┘
```

---

## Step 1: Create S3 Bucket

**Cloud storage for your application data**

📚 **What is S3?** [INFRASTRUCTURE.md#s3-bucket](INFRASTRUCTURE.md#s3-bucket)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-s3-bucket.yml --vault-password-file ~/.vault_pass
```

### Option B: AWS CLI (5 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Then create S3 bucket:**
```bash
# Create bucket with encryption
aws s3api create-bucket \
    --bucket ${app_name}-data \
    --region $aws_region \
    --create-bucket-configuration LocationConstraint=$aws_region

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket ${app_name}-data \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket ${app_name}-data \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket ${app_name}-data \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Option C: AWS Console (Point & Click)

→ [INFRASTRUCTURE.md#option-c-create-via-aws-console](INFRASTRUCTURE.md#option-c-create-via-aws-console)

**Verify:**
```bash
aws s3 ls | grep ${app_name}-data
```

---

## Step 2: Create IAM Role

**Permissions for EC2 to access S3 and other AWS services**

📚 **What is IAM?** [INFRASTRUCTURE.md#iam-role](INFRASTRUCTURE.md#iam-role)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-iam-role.yml --vault-password-file ~/.vault_pass
```

### Option B: AWS CLI (10 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Create IAM role:**
```bash
# Create trust policy (who can assume this role)
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
    --role-name ${app_name}-ec2-role \
    --assume-role-policy-document file:///tmp/trust-policy.json

# Create inline policy for S3 access
cat > /tmp/s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::${app_name}-data",
      "arn:aws:s3:::${app_name}-data/*"
    ]
  }]
}
EOF

aws iam put-role-policy \
    --role-name ${app_name}-ec2-role \
    --policy-name ${app_name}-s3-access \
    --policy-document file:///tmp/s3-policy.json

# Create instance profile
aws iam create-instance-profile \
    --instance-profile-name ${app_name}-ec2-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
    --role-name ${app_name}-ec2-role \
    --instance-profile-name ${app_name}-ec2-profile
```

**Verify:**
```bash
aws iam get-role --role-name ${app_name}-ec2-role
```

---

## Step 3: Create Security Group

**Firewall rules - which ports can receive traffic**

📚 **What is a Security Group?** [INFRASTRUCTURE.md#security-group](INFRASTRUCTURE.md#security-group)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-security-group.yml --vault-password-file ~/.vault_pass
```

### Option B: AWS CLI (5 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Create security group:**
```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name ${app_name}-sg \
    --description "Security group for ${app_display_name}" \
    --query 'GroupId' \
    --output text)

echo "Security Group ID: $SG_ID"

# Add ingress rules
# HTTP
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# HTTPS
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# SSH (admin access only)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# Tag the security group
aws ec2 create-tags \
    --resources $SG_ID \
    --tags Key=Name,Value=${app_name}-sg Key=Application,Value=${app_name}
```

**Verify:**
```bash
aws ec2 describe-security-groups --group-names ${app_name}-sg
```

---

## Step 4: Create SSH Key Pair

**Password-less authentication to your server**

📚 **What is SSH?** [INFRASTRUCTURE.md#ssh-key-pair](INFRASTRUCTURE.md#ssh-key-pair)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-ssh-key.yml --vault-password-file ~/.vault_pass
```

### Option B: AWS CLI (2 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Create SSH key:**
```bash
# Create key pair
aws ec2 create-key-pair \
    --key-name ${app_name}-key \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/${app_name}-key.pem

# Set proper permissions (required for SSH to work)
chmod 400 ~/.ssh/${app_name}-key.pem

# Verify
ls -la ~/.ssh/${app_name}-key.pem
```

---

## Step 5: Launch EC2 Instance

**Create the actual server that runs your application**

📚 **What is EC2?** [INFRASTRUCTURE.md#ec2-instance](INFRASTRUCTURE.md#ec2-instance)

### Option A: Ansible Playbook (Recommended - 3 minutes)

```bash
cd deployment
ansible-playbook playbooks/launch-ec2-instance.yml --vault-password-file ~/.vault_pass
```

**Check results:**
```bash
cat deployment/instance-info.txt
```

### Option B: AWS CLI (5 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Get required information:**
```bash
# Get security group ID
SG_ID=$(aws ec2 describe-security-groups \
    --group-names ${app_name}-sg \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# Get instance profile ARN
PROFILE_ARN=$(aws iam get-instance-profile \
    --instance-profile-name ${app_name}-ec2-profile \
    --query 'InstanceProfile.Arn' \
    --output text)

# Get latest Ubuntu 22.04 LTS AMI
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "SG_ID: $SG_ID"
echo "PROFILE_ARN: $PROFILE_ARN"
echo "AMI_ID: $AMI_ID"
```

**Launch instance:**
```bash
# Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t3.micro \
    --key-name ${app_name}-key \
    --security-group-ids $SG_ID \
    --iam-instance-profile Arn=$PROFILE_ARN \
    --ebs-optimized \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${app_name}-server},{Key=Application,Value=${app_name}}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to have public IP
echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Instance IP: $PUBLIC_IP"
echo ""
echo "Save this for next steps:"
echo "  SERVER_IP=$PUBLIC_IP"
```

**Verify:**
```bash
# Check instance is running
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}-server" \
    --query 'Reservations[0].Instances[0].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'
```

---

## Step 6: Deploy Application to Server

**Install application code, dependencies, and start services**

### Before You Continue

You now have infrastructure. Next step: deploy the application on it.

**Get your server IP first:**
```bash
# If you just launched the instance
export SERVER_IP=<YOUR_SERVER_IP>

# Or retrieve it
cd deployment
source scripts/load-vars.sh
export SERVER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}-server" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Server IP: $SERVER_IP"
```

**Option A: Full Automated Setup (Recommended - 10 minutes)**

```bash
cd deployment

# Update inventory
sed -i.bak "s/ansible_host:.*/ansible_host: $SERVER_IP/" inventories/hosts.yml

# Deploy everything
ansible-playbook -i inventories playbooks/setup.yml --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Installs Python, Nginx, dependencies
- ✅ Creates app user (restricted permissions)
- ✅ Clones your Git repository
- ✅ Sets up Python virtual environment
- ✅ Configures Nginx web server
- ✅ Creates systemd service (auto-start)
- ✅ Applies security hardening
- ✅ Starts the application

**Verify it worked:**
```bash
curl http://$SERVER_IP
# Should show your application
```

**Option B: Manual SSH Setup (Educational - 30 minutes)**

→ [Step 6 Manual Setup](#step-6-manual-ssh-deploy-application) (below)

---

## Step 6 Manual SSH Deploy Application

**For learning - do everything yourself on the server**

**First, set your server IP:**
```bash
export SERVER_IP=<YOUR_SERVER_IP>
export APP_NAME=rampe  # Change this to your app_name
export APP_USER=${APP_NAME}
export APP_DISPLAY_NAME="Rampe Application"  # Change to your app_display_name
```

### 1. Connect to Server

```bash
ssh -i ~/.ssh/${APP_NAME}-key.pem ubuntu@$SERVER_IP

# Commands after this run on the SERVER
```

### 2. Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git
```

### 3. Clone Application

```bash
# Clone from Git repository
cd /home/ubuntu
git clone https://github.com/YOUR_USERNAME/your_app.git
cd your_app

# (If private repo, configure Git credentials first)
```

### 4. Create Python Virtual Environment

```bash
# Create isolated Python environment
python3 -m venv ~/.venv
source ~/.venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### 5. Create Application User

```bash
# Create non-root user to run the app
sudo useradd -r -s /usr/sbin/nologin ${APP_USER}

# Create app data directory
sudo mkdir -p /var/log/${APP_NAME}
sudo chown ${APP_USER}:${APP_USER} /var/log/${APP_NAME}
```

### 6. Create Systemd Service

```bash
# Create service file (auto-start and restart app)
sudo tee /etc/systemd/system/${APP_NAME}.service > /dev/null <<EOF
[Unit]
Description=${APP_DISPLAY_NAME}
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=/home/ubuntu/${APP_NAME}
Environment="PATH=/home/ubuntu/.venv/bin"
ExecStart=/home/ubuntu/.venv/bin/gunicorn \
    --bind 127.0.0.1:8000 \
    --workers 4 \
    --timeout 120 \
    --access-logfile /var/log/${APP_NAME}/access.log \
    --error-logfile /var/log/${APP_NAME}/error.log \
    "app:create_app('production')"

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}
sudo systemctl start ${APP_NAME}
```

### 7. Configure Nginx

```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/${APP_NAME} > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # Serve static files directly
    location /static/ {
        alias /home/ubuntu/${APP_NAME}/app/static/;
    }

    # Forward everything else to Gunicorn
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site and disable default
sudo ln -s /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl restart nginx
```

### 8. Verify Everything Works

```bash
# Check services are running
sudo systemctl status ${APP_NAME}
sudo systemctl status nginx

# Check logs
sudo journalctl -u ${APP_NAME} -n 20
```

### 9. Exit Server

```bash
exit
```

### 10. Test from Your Computer

```bash
curl http://$SERVER_IP
# Should show your application
```

---

## Step 7: Configure SSL/HTTPS (Optional)

**Only if you have a custom domain**

If you're just using IP address, you can skip this.

📚 **How to configure SSL?** See:

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Quick:** Playbook version
```bash
ansible-playbook -i inventories playbooks/setup-ssl.yml --vault-password-file ~/.vault_pass
```

**Manual way:**
```bash
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP

# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email your.email@example.com \
  --domains ${server_name} \
  --redirect

exit
```

**Verify:**
```bash
curl https://${server_name}
# Should show application over HTTPS
```

---

## Step 8: Setup Monitoring (Optional)

**Track logs and metrics in CloudWatch**

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Run monitoring playbook:**
```bash
ansible-playbook -i inventories playbooks/setup-monitoring.yml --vault-password-file ~/.vault_pass
```

**View logs:**
- AWS Console → CloudWatch → Logs
- Look for `/${app_name}/`

**Create Dashboards & Alarms (Recommended):**

Now that logs are being collected, create alarms to detect problems and dashboards to monitor health.

→ **[MONITORING.md](MONITORING.md)** - Full guide to set up alarms for errors, high CPU, disk space, and attacks

---

## Verification Checklist

**After deployment, verify everything:**

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Then run checks:**
```bash
# ✅ Can you access the application?
curl http://$SERVER_IP
# Should show your app homepage

# ✅ Is the app service running?
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
sudo systemctl status ${app_name}
exit

# ✅ Is Nginx running?
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
sudo systemctl status nginx
exit

# ✅ Can you see EC2 instance in AWS?
aws ec2 describe-instances --filters "Name=tag:Name,Values=${app_name}-server"

# ✅ Does S3 bucket exist?
aws s3 ls | grep ${app_name}-data

# ✅ Is IAM role attached?
aws iam get-role --role-name ${app_name}-ec2-role
```

**All checks pass?** 🎉 **Deployment complete!**

---

## Troubleshooting

### Can't SSH to Server

```bash
# Check SSH key has correct permissions
ls -la ~/.ssh/${app_name}-key.pem
# Should show: -rw------- (600 or 400)

# If wrong:
chmod 400 ~/.ssh/${app_name}-key.pem

# Try SSH again with verbose
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP -v
# -v shows verbose output if error occurs
```

### Application Won't Start

```bash
# SSH to server
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP

# Check service status
sudo systemctl status ${app_name}

# View error logs
sudo journalctl -u ${app_name} -n 50 --no-pager

# Check if port 8000 is listening
sudo netstat -tulpn | grep 8000

exit
```

### Can't Access Application

```bash
# First load variables
cd deployment
source scripts/load-vars.sh

# Check if Nginx is running
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
sudo systemctl status nginx

# Check Nginx configuration
sudo nginx -t

# Check security group allows port 80
aws ec2 describe-security-groups \
  --group-names ${app_name}-sg \
  --query 'SecurityGroups[0].IpPermissions'
# Should show port 80 and 443

exit
```

### S3 Permissions Denied

```bash
# First load variables
cd deployment
source scripts/load-vars.sh

# Check IAM role is attached to instance
aws iam get-instance-profile --instance-profile-name ${app_name}-ec2-profile

# Check instance has role
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${app_name}-server" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
# Should show the role ARN
```

---

## Next Steps

**After successful deployment:**

- **Operations & Maintenance:** [OPERATIONS.md](OPERATIONS.md)
- **Add Multiple Users:** [MULTI_USER.md](MULTI_USER.md)
- **Manage Secrets:** [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)
- **Security Details:** [../reference/SECURITY.md](../reference/SECURITY.md)
- **All Playbooks Reference:** [../reference/PLAYBOOKS.md](../reference/PLAYBOOKS.md)

---

## Summary

**You deployed:**
- ✅ AWS infrastructure (S3, EC2, IAM, Security Groups)
- ✅ Application with Gunicorn + Nginx
- ✅ Systemd service (auto-restart)
- ✅ (Optional) SSL/HTTPS
- ✅ (Optional) CloudWatch monitoring

**You learned:**
- How AWS services work (not just commands)
- Both automated (playbook) and manual (CLI) approaches
- What each component does and why
- How to use variables in CLI commands

**Architecture is now:**
- Scalable (can add more servers)
- Secure (no credentials on server, IAM roles)
- Maintainable (systemd auto-restart)
- Observable (CloudWatch logs)

---

## Quick Links

| Task | Time | Link |
|------|------|------|
| **First time?** | 15 min | [PREREQUISITES.md](PREREQUISITES.md) |
| **Just deploy** | 20 min | [QUICKSTART.md](QUICKSTART.md) |
| **Learn details** | 1-2 hrs | This guide |
| **Infrastructure only** | 15 min | [INFRASTRUCTURE.md](INFRASTRUCTURE.md) |
| **Daily operations** | Reference | [OPERATIONS.md](OPERATIONS.md) |
| **Architecture** | Reference | [../reference/ARCHITECTURE.md](../reference/ARCHITECTURE.md) |


### Overview: What Gets Deployed

```
Your Local Machine
       ↓
 [Infrastructure Layer] ← Steps 1-5 below
       ↓
┌─────────────────────────┐
│   AWS Region (us-east-2) │
├─────────────────────────┤
│                         │
│  EC2 Instance (Ubuntu)  │
│  - Nginx (web server)   │
│  - Gunicorn (app)       │
│  - Systemd (auto-start) │
│                         │
│  ↓ Stores data to:      │
│  S3 Bucket (storage)    │
│                         │
│  ↓ Uses role:           │
│  IAM Role (permissions) │
│                         │
└─────────────────────────┘
```

---

## Step 1: Create S3 Bucket

**Cloud storage for your application data**

📚 **What is S3?** [INFRASTRUCTURE.md#s3-bucket](INFRASTRUCTURE.md#s3-bucket)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-s3-bucket.yml
```

### Option B: AWS CLI (5 minutes)

→ [INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli](INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-1)

### Option C: AWS Console (Point & Click)

→ [INFRASTRUCTURE.md#option-c-create-via-aws-console](INFRASTRUCTURE.md#option-c-create-via-aws-console)

**Verify:**
```bash
aws s3 ls | grep {app_name}
```

---

## Step 2: Create IAM Role

**Permissions for EC2 to access S3 and other AWS services**

📚 **What is IAM?** [INFRASTRUCTURE.md#iam-role](INFRASTRUCTURE.md#iam-role)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-iam-role.yml
```

### Option B: AWS CLI (10 minutes)

→ [INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-1](INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-1)

**Verify:**
```bash
aws iam get-role --role-name {app_name}-ec2-role
```

---

## Step 3: Create Security Group

**Firewall rules - which ports can receive traffic**

📚 **What is a Security Group?** [INFRASTRUCTURE.md#security-group](INFRASTRUCTURE.md#security-group)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-security-group.yml
```

### Option B: AWS CLI (5 minutes)

→ [INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-2](INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-2)

**Verify:**
```bash
aws ec2 describe-security-groups --group-names {app_name}-sg
```

---

## Step 4: Create SSH Key Pair

**Password-less authentication to your server**

📚 **What is SSH?** [INFRASTRUCTURE.md#ssh-key-pair](INFRASTRUCTURE.md#ssh-key-pair)

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/create-ssh-key.yml
```

### Option B: AWS CLI (2 minutes)

→ [INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-3](INFRASTRUCTURE.md#option-b-create-manually-via-aws-cli-3)

**Verify:**
```bash
ls -la ~/.ssh/{app_name}-key.pem
```

---

## Step 5: Launch EC2 Instance

**Create the actual server that runs your application**

📚 **What is EC2?** [INFRASTRUCTURE.md#ec2-instance](INFRASTRUCTURE.md#ec2-instance)

### Option A: Ansible Playbook (Recommended - 3 minutes)

```bash
cd deployment
ansible-playbook playbooks/launch-ec2-instance.yml
```

**Check results:**
```bash
cat deployment/instance-info.txt
```

### Option B: AWS CLI (5 minutes)

→ [INFRASTRUCTURE.md#option-b-launch-manually-via-aws-cli](INFRASTRUCTURE.md#option-b-launch-manually-via-aws-cli)

**Verify:**
```bash
# Check instance running
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"

# Get your instance IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values={app_name}-server" \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

---

## Step 6: Deploy Application to Server

**Install application code, dependencies, and start services**

### Before You Continue

You now have infrastructure. Next step: deploy the application on it.

**Option A: Full Automated Setup (Recommended - 10 minutes)**

```bash
cd deployment

# Edit inventory with your instance IP (if playbook didn't save it)
nano inventories/hosts.yml
# Set: ansible_host: YOUR_SERVER_IP

# Deploy everything
ansible-playbook -i inventories playbooks/setup.yml
```

**What it does:**
- ✅ Installs Python, Nginx, dependencies
- ✅ Creates app user (restricted permissions)
- ✅ Clones your Git repository
- ✅ Sets up Python virtual environment
- ✅ Configures Nginx web server
- ✅ Creates systemd service (auto-start)
- ✅ Applies security hardening
- ✅ Starts the application

**Verify it worked:**
```bash
curl http://YOUR_SERVER_IP
# Should show your application
```

**Option B: Manual SSH Setup (Educational - 30 minutes)**

→ [Step 6 Manual Setup](#step-6-manual-ssh-deploy-application) (below)

---

## Step 6 Manual SSH Deploy Application

**For learning - do everything yourself on the server**

### 1. Connect to Server

```bash
# SSH into server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Commands after this run on the SERVER
```

### 2. Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git
```

### 3. Clone Application

```bash
# Clone from Git repository
cd /home/ubuntu
git clone https://github.com/YOUR_USERNAME/your_app.git
cd your_app

# (If private repo, configure Git credentials first)
```

### 4. Create Python Virtual Environment

```bash
# Create isolated Python environment
python3 -m venv ~/.venv
source ~/.venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### 5. Create Application User

```bash
# Create non-root user to run the app
sudo useradd -r -s /usr/sbin/nologin {app_username}

# Create app data directory
sudo mkdir -p /var/log/{app_name}
sudo chown {app_username}:{app_username} /var/log/{app_name}
```

### 6. Create Systemd Service

```bash
# Create service file (auto-start and restart app)
sudo tee /etc/systemd/system/{app_name}.service > /dev/null <<'EOF'
[Unit]
Description={app_display_name}
After=network.target

[Service]
Type=simple
User={app_username}
Group={app_username}
WorkingDirectory=/home/ubuntu/{app_name}
Environment="PATH=/home/ubuntu/.venv/bin"
ExecStart=/home/ubuntu/.venv/bin/gunicorn \
    --bind 127.0.0.1:8000 \
    --workers 4 \
    --timeout 120 \
    --access-logfile /var/log/{app_name}/access.log \
    --error-logfile /var/log/{app_name}/error.log \
    "app:create_app('production')"

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable {app_name}
sudo systemctl start {app_name}
```

### 7. Configure Nginx

```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/{app_name} > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # Serve static files directly
    location /static/ {
        alias /home/ubuntu/{app_name}/app/static/;
    }

    # Forward everything else to Gunicorn
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site and disable default
sudo ln -s /etc/nginx/sites-available/{app_name} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl restart nginx
```

### 8. Verify Everything Works

```bash
# Check services are running
sudo systemctl status {app_name}
sudo systemctl status nginx

# Check logs
sudo journalctl -u {app_name} -n 20
```

### 9. Exit Server

```bash
exit
```

### 10. Test from Your Computer

```bash
curl http://YOUR_SERVER_IP
# Should show your application
```

---

## Step 7: Configure SSL/HTTPS (Optional)

**Only if you have a custom domain**

If you're just using IP address, you can skip this.

📚 **How to configure SSL?** See:
- **Quick:** Playbook version
- **Educational:** Manual certbot commands

```bash
# Edit config first
cd deployment
nano group_vars/all.yml
# Set: server_name: "your-domain.com"

# Run playbook
ansible-playbook -i inventories playbooks/setup-ssl.yml
```

**Manual way:**
```bash
# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email your.email@example.com \
  --domains your-domain.com \
  --redirect

exit
```

**Verify:**
```bash
curl https://your-domain.com
# Should show application over HTTPS
```

---

## Step 8: Setup Monitoring (Optional)

**Track logs and metrics in CloudWatch**

```bash
cd deployment

# Run monitoring playbook
ansible-playbook -i inventories playbooks/setup-monitoring.yml
```

**View logs:**
- AWS Console → CloudWatch → Logs
- Look for `/{app_name}/`

**Create Dashboards & Alarms (Recommended):**

Now that logs are being collected, create alarms to detect problems and dashboards to monitor health.

→ **[MONITORING.md](MONITORING.md)** - Full guide to set up alarms for errors, high CPU, disk space, and attacks

---

## Verification Checklist

**After deployment, verify everything:**

```bash
# ✅ Can you access the application?
curl http://YOUR_SERVER_IP
# Should show your app homepage

# ✅ Is the app service running?
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo systemctl status {app_name}
exit

# ✅ Is Nginx running?
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo systemctl status nginx
exit

# ✅ Can you see EC2 instance in AWS?
aws ec2 describe-instances --filters "Name=tag:Name,Values={app_name}-server"

# ✅ Does S3 bucket exist?
aws s3 ls | grep {app_name}

# ✅ Is IAM role attached?
aws iam get-role --role-name {app_name}-ec2-role
```

**All checks pass?** 🎉 **Deployment complete!**

---

## Troubleshooting

### Can't SSH to Server

```bash
# Check SSH key has correct permissions
ls -la ~/.ssh/{app_name}-key.pem
# Should show: -rw------- (600)

# If wrong:
chmod 400 ~/.ssh/{app_name}-key.pem

# Try SSH again
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP -v
# -v shows verbose output if error occurs
```

### Application Won't Start

```bash
# SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check service status
sudo systemctl status {app_name}

# View error logs
sudo journalctl -u {app_name} -n 50 --no-pager

# Check if port 8000 is listening
sudo netstat -tulpn | grep 8000
```

### Can't Access Application

```bash
# Check if Nginx is running
sudo systemctl status nginx

# Check Nginx configuration
sudo nginx -t

# Check security group allows port 80
aws ec2 describe-security-groups \
  --group-names {app_name}-sg \
  --query 'SecurityGroups[0].IpPermissions'
# Should show port 80 and 443
```

### S3 Permissions Denied

```bash
# Check IAM role is attached to instance
aws iam get-instance-profile --instance-profile-name {app_name}-ec2-role

# Check instance has role
aws ec2 describe-instances \
  --filters "Name:tag:Name,Values={app_name}-server" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
# Should show the role ARN
```

---

## Next Steps

**After successful deployment:**

- **Operations & Maintenance:** [OPERATIONS.md](OPERATIONS.md)
- **Add Multiple Users:** [MULTI_USER.md](MULTI_USER.md)
- **Manage Secrets:** [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)
- **Security Details:** [../reference/SECURITY.md](../reference/SECURITY.md)
- **All Playbooks Reference:** [../reference/PLAYBOOKS.md](../reference/PLAYBOOKS.md)

---

## Summary

**You deployed:**
- ✅ AWS infrastructure (S3, EC2, IAM, Security Groups)
- ✅ Application with Gunicorn + Nginx
- ✅ Systemd service (auto-restart)
- ✅ (Optional) SSL/HTTPS
- ✅ (Optional) CloudWatch monitoring

**You learned:**
- How AWS services work (not just commands)
- Both automated (playbook) and manual (CLI) approaches
- What each component does and why

**Architecture is now:**
- Scalable (can add more servers)
- Secure (no credentials on server, IAM roles)
- Maintainable (systemd auto-restart)
- Observable (CloudWatch logs)

---

## Quick Links

| Task | Time | Link |
|------|------|------|
| **First time?** | 15 min | [PREREQUISITES.md](PREREQUISITES.md) |
| **Just deploy** | 20 min | [QUICKSTART.md](QUICKSTART.md) |
| **Learn details** | 1-2 hrs | This guide |
| **Infrastructure only** | 15 min | [INFRASTRUCTURE.md](INFRASTRUCTURE.md) |
| **Daily operations** | Reference | [OPERATIONS.md](OPERATIONS.md) |
| **Architecture** | Reference | [../reference/ARCHITECTURE.md](../reference/ARCHITECTURE.md) |

