# Manual Deployment Guide

**Complete step-by-step deployment with full control**

---

## Table of Contents

**Quick Navigation** - Click to jump to any step:

- [Prerequisites](#prerequisites)
- [Step 1: Provision Infrastructure](#step-1-provision-infrastructure)
  - [Option A: Playbook](#option-a-playbook-provision-infrastructure)
  - [Option B: AWS CLI](#option-b-aws-cli-provision-infrastructure)
- [Step 2: Deploy Application](#step-2-deploy-application)
  - [Option A: Playbook](#option-a-playbook-deploy-application)
  - [Option B: Manual SSH](#option-b-manual-ssh-deploy-application)
- [Step 3: Configure SSL (Optional)](#step-3-configure-ssl-optional)
  - [Option A: Playbook](#option-a-playbook-configure-ssl)
  - [Option B: Manual certbot](#option-b-manual-certbot-configure-ssl)
- [Step 4: Setup Monitoring (Optional)](#step-4-setup-monitoring-optional)
  - [Option A: Playbook](#option-a-playbook-setup-monitoring)
  - [Option B: Manual CloudWatch](#option-b-manual-cloudwatch-setup-monitoring)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

**Before you start, you need:**

### Tools Installed
```bash
# Verify you have everything
aws sts get-caller-identity     # AWS CLI configured
python3 --version               # Python 3.8+
ansible --version               # Ansible 2.9+
git --version                   # Git installed
```

**If any command fails, install:**

```bash
# Install Python dependencies
pip3 install -r deployment/requirements.txt

# Configure AWS CLI
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (us-east-2), Output format (json)

# Verify git is configured
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Configuration Ready
- `deployment/group_vars/all.yml` - Set `app_name` and `app_display_name`
- `deployment/group_vars/vault.yml` - Create encrypted secrets vault
- `~/.vault_pass` - Vault password file

**Setup configuration:**

```bash
cd deployment

# 1. Edit app configuration
nano group_vars/all.yml
# Set: app_name: your_app_name
# Set: app_display_name: "Your App Name"

# 2. Create vault password
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# 3. Create encrypted vault
ansible-vault create group_vars/vault.yml --vault-password-file ~/.vault_pass
# Add your secrets (git repo, S3 bucket, app password, etc.)
```

---

## Step 1: Provision Infrastructure

**Create AWS resources: S3 bucket, IAM role, EC2 instance, security group, SSH key**

### Option A: Playbook (Provision Infrastructure)

**Recommended - Automated and idempotent**

**Option A1: Run orchestration playbook (all at once)**

```bash
cd deployment

# Single command creates all infrastructure
ansible-playbook playbooks/provision-infrastructure.yml
```

**What it creates:**
- ✅ S3 bucket with versioning and encryption
- ✅ IAM role with S3, Secrets Manager, CloudWatch access
- ✅ Security group (ports 22, 80, 443)
- ✅ SSH key pair (saved to `~/.ssh/{app_name}-key.pem`)
- ✅ EC2 instance (Ubuntu 22.04, t3.micro)
- ✅ Instance info saved to `deployment/instance-info.txt`

**Duration:** 5-7 minutes

**Option A2: Run individual playbooks (validate each step)**

```bash
cd deployment

# 1. Create S3 bucket
ansible-playbook playbooks/create-s3-bucket.yml
# Verify: aws s3 ls | grep your-bucket

# 2. Create IAM role
ansible-playbook playbooks/create-iam-role.yml
# Verify: aws iam get-role --role-name {app_name}-ec2-role

# 3. Create security group
ansible-playbook playbooks/create-security-group.yml
# Verify: aws ec2 describe-security-groups --group-names {app_name}-sg

# 4. Create SSH key
ansible-playbook playbooks/create-ssh-key.yml
# Verify: ls ~/.ssh/{app_name}-key.pem

# 5. Launch EC2 instance
ansible-playbook playbooks/launch-ec2-instance.yml
# Verify: Check instance-info.txt
```

**Duration:** 5-10 minutes (with validation steps)

**Benefits of individual playbooks:**
- Validate each component in AWS console
- Debug which component failed
- Re-run specific component if needed
- Skip components you already have

[Back to top](#table-of-contents)

### Option B: AWS CLI (Provision Infrastructure)

**Manual control - Step by step**

```bash
# 1. Create S3 bucket
aws s3 mb s3://yourname-yourapp-2026 --region us-east-2

# 2. Create SSH key pair
aws ec2 create-key-pair \
  --key-name {app_name}-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/{app_name}-key.pem
chmod 400 ~/.ssh/{app_name}-key.pem

# 3. Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name {app_name}-sg \
  --description "Security group for {app_name}" \
  --query 'GroupId' \
  --output text)

# 4. Add security group rules
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# 5. Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region us-east-2)

# 6. Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name {app_name}-key \
  --security-group-ids $SG_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value={app_name}}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region us-east-2)

# 7. Wait for instance to start
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-east-2

# 8. Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region us-east-2)

echo "Instance IP: $INSTANCE_IP"
echo "SSH: ssh -i ~/.ssh/{app_name}-key.pem ubuntu@$INSTANCE_IP"

# 9. Update inventory file
# Edit deployment/inventories/hosts.yml
# Set: ansible_host: $INSTANCE_IP
```

**What you created:**
- ✅ S3 bucket for application data
- ✅ EC2 instance with security group
- ✅ SSH key pair for access

**Duration:** 5-10 minutes (manual steps)

**Next:** Update `deployment/inventories/hosts.yml` with instance IP

[Back to top](#table-of-contents)

---

## Step 2: Deploy Application

**Install application, configure nginx, start services**

### Option A: Playbook (Deploy Application)

**Recommended - Complete deployment**

```bash
cd deployment

# Update inventory with server IP (if not done)
nano inventories/hosts.yml
# Set: ansible_host: YOUR_SERVER_IP

# Deploy application
ansible-playbook -i inventories playbooks/setup.yml
```

**What it does:**
- ✅ Updates system packages
- ✅ Installs Python 3.10, Nginx, dependencies
- ✅ Creates app user (restricted permissions)
- ✅ Clones repository
- ✅ Sets up virtual environment
- ✅ Configures systemd service
- ✅ Configures nginx
- ✅ Applies security hardening
- ✅ Starts application

**Duration:** 10-15 minutes

**Verify:**
```bash
curl http://YOUR_SERVER_IP
# Should show your application
```

[Back to top](#table-of-contents)

### Option B: Manual SSH (Deploy Application)

**Manual control - Run commands on server**

```bash
# 1. SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# 2. Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-venv nginx

# 3. Clone repository
cd /home/ubuntu
git clone https://github.com/YOUR_USERNAME/your_app.git
cd your_app

# 4. Create virtual environment
python3 -m venv ~/.venv
source ~/.venv/bin/activate
pip install -r requirements.txt

# 5. Create app user
sudo useradd -r -s /usr/sbin/nologin {app_name}
sudo mkdir -p /var/log/{app_name}
sudo chown {app_name}:{app_name} /var/log/{app_name}
sudo chown {app_name}:{app_name} /home/ubuntu/{app_name}/instance

# 6. Create systemd service
sudo tee /etc/systemd/system/{app_name}.service > /dev/null <<EOF
[Unit]
Description={App Name} Application
After=network.target

[Service]
Type=simple
User={app_name}
Group={app_name}
WorkingDirectory=/home/ubuntu/{app_name}
Environment="PATH=/home/ubuntu/.venv/bin"
EnvironmentFile=/home/ubuntu/{app_name}/.env
ExecStart=/home/ubuntu/.venv/bin/gunicorn \\
    --bind 127.0.0.1:8000 \\
    --workers 4 \\
    --timeout 120 \\
    --access-logfile /var/log/{app_name}/access.log \\
    --error-logfile /var/log/{app_name}/error.log \\
    "app:create_app('production')"

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 7. Configure nginx
sudo tee /etc/nginx/sites-available/{app_name} > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location /static/ {
        alias /home/ubuntu/{app_name}/app/static/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/{app_name} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 8. Start services
sudo systemctl daemon-reload
sudo systemctl enable {app_name}
sudo systemctl start {app_name}
sudo systemctl restart nginx

# 9. Verify
sudo systemctl status {app_name}
sudo systemctl status nginx

# 10. Exit server
exit
```

**Verify from local machine:**
```bash
curl http://YOUR_SERVER_IP
# Should show your application
```

[Back to top](#table-of-contents)

---

## Step 3: Configure SSL (Optional)

**Add HTTPS with Let's Encrypt - Only if you have a custom domain**

**Skip this if accessing via IP only**

### Prerequisites
1. Domain name pointing to your server IP (A record configured)
2. DNS propagation complete (test with `nslookup your-domain.com`)
3. Set `server_name` in `deployment/group_vars/all.yml`

### Option A: Playbook (Configure SSL)

**Recommended - Automated SSL setup**

```bash
cd deployment

# 1. Configure domain in group_vars/all.yml
nano group_vars/all.yml
# Set: server_name: "your-domain.com"

# 2. Run SSL playbook
ansible-playbook -i inventories playbooks/setup-ssl.yml
```

**What it does:**
- ✅ Installs certbot and nginx plugin
- ✅ Obtains Let's Encrypt certificate
- ✅ Configures nginx for HTTPS
- ✅ Sets up auto-renewal (daily cron)
- ✅ Reloads nginx

**Duration:** 2-3 minutes

**Verify:**
```bash
curl https://your-domain.com
# Should show your application over HTTPS
```

[Back to top](#table-of-contents)

### Option B: Manual certbot (Configure SSL)

**Manual SSL setup on server**

```bash
# 1. SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# 2. Install certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# 3. Obtain certificate
sudo certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email your.email@example.com \
  --domains your-domain.com \
  --redirect

# 4. Test nginx configuration
sudo nginx -t

# 5. Reload nginx
sudo systemctl reload nginx

# 6. Setup auto-renewal
echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'" | sudo crontab -

# 7. Verify certificate
sudo certbot certificates

# 8. Exit server
exit
```

**Verify from local machine:**
```bash
curl https://your-domain.com
# Should show your application over HTTPS with valid certificate
```

[Back to top](#table-of-contents)

---

## Step 4: Setup Monitoring (Optional)

**Configure CloudWatch logs and metrics**

### Option A: Playbook (Setup Monitoring)

**Recommended - Complete monitoring setup**

```bash
cd deployment

# Run monitoring playbook
ansible-playbook -i inventories playbooks/setup-monitoring.yml
```

**What it does:**
- ✅ Installs CloudWatch agent
- ✅ Configures log shipping (app logs, nginx logs)
- ✅ Configures metrics (CPU, disk, memory)
- ✅ Creates log monitoring script
- ✅ Sets up monitoring cron (every 5 minutes)
- ✅ Configures log rotation

**Duration:** 3-5 minutes

**View logs:**
- AWS Console → CloudWatch → Logs → `/your-app-name/`

[Back to top](#table-of-contents)

### Option B: Manual CloudWatch (Setup Monitoring)

**Manual monitoring setup**

```bash
# 1. SSH to server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# 2. Install CloudWatch agent
sudo apt update
sudo apt install -y amazon-cloudwatch-agent

# 3. Create CloudWatch config
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/config.json > /dev/null <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/{app_name}/app.log",
            "log_group_name": "/{app_name}/application",
            "log_stream_name": "{instance_id}/app"
          },
          {
            "file_path": "/var/log/nginx/{app_name}_access.log",
            "log_group_name": "/{app_name}/nginx-access",
            "log_stream_name": "{instance_id}/access"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "{app_name}",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# 4. Start CloudWatch agent
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent

# 5. Verify
sudo systemctl status amazon-cloudwatch-agent

# 6. Exit server
exit
```

**View logs:**
- Wait 5-10 minutes for initial data
- AWS Console → CloudWatch → Logs

[Back to top](#table-of-contents)

---

## Verification

### Check Application Status

```bash
# Check HTTP access
curl http://YOUR_SERVER_IP
# or
curl https://your-domain.com

# Check logs on server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo journalctl -u {app_name} -n 50
sudo tail -f /var/log/nginx/{app_name}_access.log
```

### Verify All Services

```bash
# On server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Application service
sudo systemctl status {app_name}

# Nginx
sudo systemctl status nginx

# CloudWatch (if configured)
sudo systemctl status amazon-cloudwatch-agent
```

**✅ Deployment complete if all services are active!**

[Back to top](#table-of-contents)

---

## Troubleshooting

### Application Won't Start

```bash
# Check logs
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo journalctl -u {app_name} -n 100 --no-pager

# Common issues:
# - Missing .env file
# - Wrong file permissions
# - Database connection errors
```

### Can't Access Application

```bash
# Check nginx
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo nginx -t
sudo systemctl status nginx

# Check security group
aws ec2 describe-security-groups \
  --group-names {app_name}-sg \
  --query 'SecurityGroups[0].IpPermissions'

# Should show ports 22, 80, 443 open
```

### SSL Certificate Fails

```bash
# Check DNS
nslookup your-domain.com
# Should return your server IP

# Check certbot logs
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
sudo cat /var/log/letsencrypt/letsencrypt.log
```


[Back to top](#table-of-contents)

---

## Next Steps

**After deployment:**

- **Operations:** [OPERATIONS.md](OPERATIONS.md) - Daily operations, updates, backups
- **Multi-User:** [MULTI_USER.md](MULTI_USER.md) - Add more users
- **Secrets:** [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md) - Rotate secrets
- **Security:** [../reference/SECURITY.md](../reference/SECURITY.md) - Security details

---

## Summary

**You just deployed:**
- ✅ AWS infrastructure (S3, EC2, security groups)
- ✅ Application with systemd service
- ✅ Nginx reverse proxy
- ✅ (Optional) SSL/HTTPS with Let's Encrypt
- ✅ (Optional) CloudWatch monitoring

**Two deployment methods:**
- **Playbook:** Fast, automated, idempotent (can run multiple times safely)
- **Manual/CLI:** Full control, step-by-step, learn what happens

**Use playbooks for production, manual for learning!**

[Back to top](#table-of-contents)

