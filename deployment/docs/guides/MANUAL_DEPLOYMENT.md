# Chapter 3: Manual Deployment

Deploy step-by-step with full explanations. Each step offers two options:
1. **Playbook** — automated with Ansible (fastest)
2. **CLI** — AWS CLI commands (educational)

For a point-and-click walkthrough using the AWS web console, see [AWS Console Deployment](AWS_CONSOLE_DEPLOYMENT.md).

> **Prerequisite:** Complete [Chapter 1: Prerequisites](PREREQUISITES.md) before continuing.

---

## Load Configuration Variables

CLI commands in this guide use `$app_name`, `$aws_region`, and other variables from `group_vars/vault.yml`. Load them once per terminal session:

```bash
cd deployment
source scripts/load-vars.sh
```

The script decrypts `vault.yml` automatically using `~/.vault_pass`. If that file does not exist, it prompts for the vault password.

After loading variables, the script asks how to set `SERVER_IP`:

| Choice | When to use |
|--------|------------|
| **1) Use an existing AWS instance** | You already provisioned an EC2 instance. The script queries AWS for the public IP and updates `inventories/hosts.yml`. |
| **2) New deployment** | No instance exists yet. The script resets `hosts.yml` to localhost so infrastructure playbooks work. |

Verify the variables loaded:

```bash
echo $app_name       # e.g., rampe
echo $aws_region     # e.g., us-east-2
echo $SERVER_IP      # e.g., 18.191.85.21 (set after choosing option 1)
```

If `echo $app_name` is blank:
- Confirm you are in the `deployment/` directory (`pwd` should end with `rampe/deployment`)
- Use `source` not `./` — running `./scripts/load-vars.sh` creates a subshell and the variables are lost
- If `group_vars/vault.yml` does not exist, run `./scripts/local-dev-setup.sh` first


---

## Deployment Steps

### Overview: What Gets Deployed

```
Your Local Machine
       ↓
 [Infrastructure Layer] ← Steps 1-6 below
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
│  ↓ Reads secrets from:  │
│  Secrets Manager         │
│                         │
│  ↓ Uses role:           │
│  IAM Role (permissions) │
│                         │
└─────────────────────────┘
```

---

## Step 0: Create GitHub Personal Access Token

**Required for private repositories.** Ansible decrypts your vault locally and passes the token to the server during `git clone`. No credentials are stored on the instance and no AWS Secrets Manager is involved.

1. Go to [github.com → Settings → Developer settings → Fine-grained tokens](https://github.com/settings/personal-access-tokens/new).
2. Create a token:
   - **Name:** `{app_name}-deploy`
   - **Repository access:** Only select repositories → your repo
   - **Permissions:** Contents → Read-only
3. Copy the token (starts with `github_pat_...`).
4. Add it to your vault:

```bash
cd deployment
EDITOR=nano ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass
```

Set these two lines (the URL stays plain — the token is separate):

```
git_repo_url: "https://github.com/YOUR_USERNAME/YOUR_APP_NAME.git"
git_token: "github_pat_YOUR_TOKEN_HERE"
```

Save and exit. The playbooks construct the authenticated URL automatically.

**Verify:**

```bash
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | grep git_
```

You should see both `git_repo_url` and `git_token` with your values.

---

## Step 1: Create S3 Bucket

**Cloud storage for your application data**

See [Infrastructure Reference — S3 Bucket](INFRASTRUCTURE.md#s3-bucket) for background.

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

> **Important:** The bucket name below must match `s3_bucket_name` in your vault.yml.
> Check it with: `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | grep s3_bucket`

```bash
# Create bucket with encryption
aws s3api create-bucket \
    --bucket $s3_bucket_name \
    --region $aws_region \
    --create-bucket-configuration LocationConstraint=$aws_region

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $s3_bucket_name \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket $s3_bucket_name \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket $s3_bucket_name \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Option C: AWS Console (Point and Click)

→ [Console Deployment — Step 1: Create S3 Bucket](AWS_CONSOLE_DEPLOYMENT.md#step-1-create-s3-bucket)


**Verify:**

> **Note:** The bucket name comes from `s3_bucket_name` in your encrypted vault, not from `app_name`.
> To find your bucket name: `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | grep s3_bucket`

```bash
# List all buckets (confirm yours appears)
aws s3api list-buckets --query 'Buckets[].Name'
```

---

## Step 2: Create IAM Role

**Permissions for EC2 to access S3 and other AWS services**

See [Infrastructure Reference — IAM Role](INFRASTRUCTURE.md#iam-role) for background.

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
      "arn:aws:s3:::${s3_bucket_name}",
      "arn:aws:s3:::${s3_bucket_name}/*"
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
    --instance-profile-name ${app_name}-instance-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
    --role-name ${app_name}-ec2-role \
    --instance-profile-name ${app_name}-instance-profile
```

### Option C: AWS Console (Point and Click)

→ [Console Deployment — Step 2: Create IAM Role](AWS_CONSOLE_DEPLOYMENT.md#step-2-create-iam-role)

**Verify:**
```bash
aws iam get-role --role-name ${app_name}-ec2-role
```

---

## Step 3: Create Security Group

**Firewall rules - which ports can receive traffic**

See [Infrastructure Reference — Security Group](INFRASTRUCTURE.md#security-group) for background.

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

### Option C: AWS Console (Point and Click)

→ [Console Deployment — Step 3: Create Security Group](AWS_CONSOLE_DEPLOYMENT.md#step-3-create-security-group)

**Verify:**
```bash
aws ec2 describe-security-groups --group-names ${app_name}-sg
```

---

## Step 4: Create SSH Key Pair

**Password-less authentication to your server**

See [Infrastructure Reference — SSH Key Pair](INFRASTRUCTURE.md#ssh-key-pair) for background.

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

### Option C: AWS Console (Point and Click)

→ [Console Deployment — Step 4: Create SSH Key Pair](AWS_CONSOLE_DEPLOYMENT.md#step-4-create-ssh-key-pair)

---

## Step 5: Launch EC2 Instance & Prepare Server

**Create the server, mount the EBS data volume, and install system packages**

See [Infrastructure Reference — EC2 Instance](INFRASTRUCTURE.md#ec2-instance) for background.

### 5a: Launch the Instance

#### Option A: Ansible Playbook (Recommended - 3 minutes)

```bash
cd deployment
ansible-playbook playbooks/launch-ec2-instance.yml --vault-password-file ~/.vault_pass
```

The playbook automatically:
- Launches the instance and waits for SSH
- Updates `inventories/hosts.yml` with the new IP
- Saves full details to `instances/`
- **Validates** SSH, EBS volume, IAM role, S3 bucket, and security group

After it completes, `$SERVER_IP` is available via `source scripts/load-vars.sh`.

#### Option B: AWS CLI (5 minutes)

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
    --instance-profile-name ${app_name}-instance-profile \
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
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${app_name}},{Key=Application,Value=${app_name}}]" \
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

#### Option C: AWS Console (Point and Click)

→ [Console Deployment — Step 5: Launch EC2 Instance](AWS_CONSOLE_DEPLOYMENT.md#step-5-launch-ec2-instance)

### 5b: Test SSH Connectivity

```bash
cd deployment
source scripts/load-vars.sh
echo $SERVER_IP

ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP "echo 'SSH OK — connected to '\$(hostname)"
```

If this fails, check:
- Security group allows port 22 (`aws ec2 describe-security-groups --group-names ${app_name}-sg`)
- SSH key has correct permissions (`chmod 400 ~/.ssh/${app_name}-key.pem`)
- Instance is running (`aws ec2 describe-instances --filters "Name=tag:Name,Values=${app_name}" --query 'Reservations[0].Instances[0].State.Name'`)

### 5c: Prepare the Server

This installs system packages, creates the app user, formats and mounts the 100 GB EBS volume at `/opt/{app_name}`, and creates the application directories. No reboot is required — the mount happens live and fstab is written for persistence.

```bash
cd deployment
ansible-playbook playbooks/setup-server.yml --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Installs Python, Nginx, git, and system dependencies
- ✅ Creates dedicated app user (restricted, no shell, no SSH)
- ✅ Detects the NVMe device (`/dev/nvme1n1`)
- ✅ Formats the EBS volume as XFS (first run only)
- ✅ Mounts EBS at `/opt/{app_name}` with fstab entry
- ✅ Creates `/opt/{app_name}`, `/opt/{app_name}/instance`, `/opt/{app_name}/logs`
- ✅ Applies security hardening (SSH lockdown, fail2ban, auto-updates, sysctl)
- ✅ `/home` is untouched — SSH keys survive reboots

**Verify EBS mount:**
```bash
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP "df -h /opt/${app_name} && ls -la /opt/${app_name}/"
```

You should see the 100 GB volume mounted at `/opt/{app_name}` and your app directories listed.

---

## Step 6: Setup Secrets Manager

**Store application secrets securely in AWS — the app fetches them at startup**

The application reads secrets (Flask key, eBay credentials, admin passwords) from AWS Secrets Manager at runtime using the IAM role created in Step 2. This step creates the secret and syncs your vault values into it.

### Option A: Ansible Playbook (Recommended - 1 minute)

```bash
cd deployment
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass
```

### Option B: AWS CLI (5 minutes)

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

**Create and populate the secret:**
```bash
# Create the Secrets Manager secret
aws secretsmanager create-secret \
    --name "${app_name}/production" \
    --description "Secrets for ${app_display_name}" \
    --secret-string '{}' \
    --region $aws_region

# Sync secrets from vault using the secret-sync playbook
ansible-playbook playbooks/secret-sync.yml --vault-password-file ~/.vault_pass
```

**Verify:**
```bash
# Confirm the secret exists
aws secretsmanager describe-secret \
    --secret-id "${app_name}/production" \
    --region $aws_region \
    --query '{Name:Name,ARN:ARN}'
```

---

## Step 7: Deploy Application

**Clone code, install dependencies, configure Nginx and Supervisor, start the app**

> Prerequisite: Step 5 must be complete (server prepared, EBS mounted).

### Option A: Ansible Playbook (Recommended - 5 minutes)

```bash
cd deployment
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Clones your Git repository to `/opt/{app_name}`
- ✅ Creates Python virtual environment and installs dependencies
- ✅ Configures Nginx web server
- ✅ Configures Supervisor process manager
- ✅ Applies security permissions
- ✅ Starts the application
- ✅ Installs SSL certificate (Let's Encrypt, auto-renewal enabled)

**Verify it worked:**
```bash
curl https://$server_name
# Should show your application over HTTPS
```

**Option B: Manual SSH Setup (Educational - 30 minutes)**

→ [Step 7b: Deploy via SSH](#step-7b-deploy-via-ssh-manual) (below)

---

## Step 7b: Deploy via SSH (Manual)

**For learning - do everything yourself on the server**

**First, load variables:**
```bash
cd deployment
source scripts/load-vars.sh
```

### 1. Connect to Server

```bash
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
```

Once connected, set variables for the server session (these do not carry over from your local machine):

```bash
# Run these on the server after connecting
export APP_NAME=rampe               # Change to your app_name
export APP_USER=app_runtime         # Change to your app_user
export APP_DISPLAY_NAME="Rampe"     # Change to your app_display_name
```

### 2. Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git
```

### 3. Clone Application

```bash
# Clone from Git repository (EBS volume is mounted at /opt/${APP_NAME})
cd /opt/${APP_NAME}
sudo chown ubuntu:${APP_NAME} /opt/${APP_NAME}
git clone https://github.com/YOUR_USERNAME/${APP_NAME}.git .

# (If private repo, configure Git credentials first —
#  see Step 0: Create GitHub Personal Access Token)
```

### 4. Create Python Virtual Environment

```bash
# Create isolated Python environment
python3 -m venv /opt/${APP_NAME}/.venv
source /opt/${APP_NAME}/.venv/bin/activate

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
WorkingDirectory=/opt/${APP_NAME}
Environment="PATH=/opt/${APP_NAME}/.venv/bin"
ExecStart=/opt/${APP_NAME}/.venv/bin/gunicorn \
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
        alias /opt/${APP_NAME}/app/static/;
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
sudo supervisorctl status ${APP_NAME}
sudo systemctl status nginx

# Check logs
sudo tail -20 /opt/${APP_NAME}/logs/app.log
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

## Step 8: Configure SSL/HTTPS

SSL is required for all production deployments. The `setup.yml` playbook installs the certificate automatically. If you ran `setup.yml` in Step 7, SSL is already configured.

**Prerequisites (must be set in vault.yml before deploying):**
- `server_name` — your domain (e.g., `myapp.example.com`)
- `ssl_email` — email for Let's Encrypt notifications
- DNS A record pointing your domain to the server IP

### If SSL was not installed during Step 7

If `setup.yml` could not reach the domain (DNS not propagated yet), run SSL separately:

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

> **Note:** `$ssl_email` and `$server_name` are local variables from `load-vars.sh`. They are passed to the SSH command below automatically — do not run this from inside an interactive SSH session.

```bash
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP bash -s <<REMOTE
  sudo apt install -y certbot python3-certbot-nginx
  sudo certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email $ssl_email \
    --domains $server_name \
    --redirect
REMOTE
```

**Verify:**
```bash
curl https://$server_name
# Should show application over HTTPS

curl -I http://$server_name
# Should show 301 redirect to HTTPS
```

For console-based SSL setup, see [Console Deployment — Step 7: Configure SSL](AWS_CONSOLE_DEPLOYMENT.md#step-7-configure-sslhttps).

---

## Step 9: Setup Monitoring (Optional)

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

For creating alarms and dashboards in the console, see [Console Deployment — Step 8: Set Up Monitoring](AWS_CONSOLE_DEPLOYMENT.md#step-8-set-up-monitoring-optional).

**Create Dashboards & Alarms (Recommended):**

Now that logs are being collected, create alarms to detect problems and dashboards to monitor health.

See [Chapter 6: Monitoring](MONITORING.md) for alarms, dashboards, and alerting.

---

## Verification

> **Note:** If you used the Ansible playbook for Step 5, SSH, EBS, IAM, S3, and security group were already validated during launch. Security hardening (SSH lockdown, fail2ban, auto-updates) is applied automatically by `setup-server.yml`. SSL is installed automatically by `setup.yml`. These commands are for manual or post-deploy checks.

```bash
cd deployment
source scripts/load-vars.sh    # loads $SERVER_IP, $app_name, $aws_region, etc.

# Application responds over HTTPS (after setup.yml has run)
curl https://$server_name

# HTTP redirects to HTTPS
curl -I http://$server_name

# EC2 instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${app_name}" \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'

# S3 bucket exists
aws s3api head-bucket --bucket $s3_bucket_name

# IAM role exists
aws iam get-role --role-name ${app_name}-ec2-role --query 'Role.RoleName'
```

On the server:

```bash
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP

# If deployed via Ansible (Steps 7):
sudo supervisorctl status ${app_name}

# If deployed via SSH (Step 7b):
sudo systemctl status ${app_name}

# Nginx (both paths):
sudo systemctl status nginx
exit
```

Every command should succeed. If any fails, see Troubleshooting below.

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
sudo supervisorctl status ${app_name}

# View error logs
sudo tail -50 /opt/${app_name}/logs/app.log

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
aws iam get-instance-profile --instance-profile-name ${app_name}-instance-profile

# Check instance has role
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${app_name}" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
# Should show the role ARN
```

---

## Next step

Continue to [Chapter 4: Updating Your Application](UPDATING_APPLICATION.md).

## See also

- [Chapter 5: Operations](OPERATIONS.md) — backups, restarts, troubleshooting
- [Chapter 7: Secret Management](SECRET_MANAGEMENT.md) — rotate credentials
- [Chapter 8: Security Hardening](SECURITY_HARDENING.md) — verify and tune hardening settings
- [Chapter 13: Decommission](DECOMMISSION.md) — tear down all resources
