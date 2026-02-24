# Infrastructure Components Guide

**Understanding and deploying each AWS component**

---

## Table of Contents

1. [S3 Bucket](#s3-bucket)
2. [IAM Role](#iam-role)
3. [Security Group](#security-group)
4. [SSH Key Pair](#ssh-key-pair)
5. [EC2 Instance](#ec2-instance)

---

## S3 Bucket

### What It Is

**S3 (Simple Storage Service)** is AWS's object storage service. Think of it as a secure, scalable cloud drive.

**Why you need it:**
- Store application files (images, uploads, backups)
- Highly available (99.99% uptime)
- Cost-effective (~$0.023 per GB/month)
- Access from anywhere with proper credentials
- Versioning and encryption built-in

**AWS Pricing:** ~$1-2/month for typical app storage (first 5GB free on free tier)

### Option A: Deploy via Playbook (Automated)

**Recommended - Sets up best practices automatically**

```bash
cd deployment

# Run S3 creation playbook
ansible-playbook playbooks/create-s3-bucket.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Creates S3 bucket with unique name from `group_vars/all.yml`
- ✅ Enables versioning (recover deleted files)
- ✅ Enables encryption (AES-256)
- ✅ Blocks public access (only authorized access)
- ✅ Saves bucket info to `instance-info.txt`

**Verify in AWS Console:**
- Go to [S3 Console](https://s3.console.aws.amazon.com/s3/)
- You should see your bucket listed
- Click it and check:
  - Properties → Versioning (should be Enabled)
  - Properties → Encryption (should be Enabled)
  - Permissions → Block Public Access (should all be Checked)

### Option B: Create Manually via AWS CLI

**Manual control - Understand each step**

```bash
# Set variables
BUCKET_NAME="yourname-{app_name}-2026"
AWS_REGION="us-east-2"

# 1. Create bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION
# Output: make_bucket: bucket_name

# 2. Enable versioning (can recover deleted/overwritten files)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 3. Enable encryption (files encrypted at rest)
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# 4. Block public access (prevent accidental public exposure)
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Verify
aws s3 ls | grep $BUCKET_NAME
# Should show your bucket
```

**Why each step:**
- **Versioning:** Mistakes happen. Versioning lets you recover old versions of files.
- **Encryption:** Your data is encrypted on AWS servers. Even AWS staff can't read your data.
- **Block Public:** Prevents accidental exposure of private data. (Like the leak that happens when someone misconfigures S3)

### Option C: Create via AWS Console (Point & Click)

**Easiest visual way**

1. Go to [S3 Console](https://s3.console.aws.amazon.com/s3/)
2. Click **Create bucket**
3. **Bucket name:** `yourname-{app_name}-2026` (must be globally unique)
4. **Region:** `us-east-2`
5. Click **Create bucket**
6. **Enable versioning:**
   - Click the bucket name
   - Properties tab → Versioning → Edit → Enable → Save changes
7. **Enable encryption:**
   - Properties tab → Encryption → Edit → AES-256 → Save changes
8. **Block public access:**
   - Permissions tab → Block public access → Edit → Check all 4 boxes → Save

---

## IAM Role

### What It Is

**IAM (Identity and Access Management)** controls who can do what in AWS.

**Why you need it:**
- Your EC2 instance needs permission to access S3, CloudWatch, Secrets Manager
- Alternative to putting credentials on the server (bad practice)
- Permission-based (server can only do what role allows)
- Can be revoked instantly if needed

**Security benefit:** No AWS credentials stored on server = if server is compromised, attacker can't access S3 or secrets directly.

### Option A: Deploy via Playbook (Automated)

**Recommended**

```bash
cd deployment

# Create IAM role with permissions
ansible-playbook playbooks/create-iam-role.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Creates IAM role named `{app_name}-ec2-role`
- ✅ Adds S3 access policy
- ✅ Adds Secrets Manager access
- ✅ Adds CloudWatch Logs access
- ✅ Creates instance profile (for EC2 to use the role)

**Verify in AWS Console:**
- Go to [IAM Roles Console](https://console.aws.amazon.com/iam/home#/roles)
- Search for `{app_name}-ec2-role`
- Click it and view attached policies (should see 3 policies)

### Option B: Create Manually via AWS CLI

**Manual control**

```bash
# Set variables
ROLE_NAME="{app_name}-ec2-role"
TRUST_POLICY='{
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
}'

# 1. Create role with trust policy (allows EC2 to assume this role)
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document "$TRUST_POLICY"

# 2. Attach S3 access policy
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# 3. Attach Secrets Manager access
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

# 4. Attach CloudWatch Logs access
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# 5. Create instance profile (for EC2 to use role)
aws iam create-instance-profile \
  --instance-profile-name $ROLE_NAME

# 6. Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name $ROLE_NAME \
  --role-name $ROLE_NAME

# 7. Verify
aws iam get-role --role-name $ROLE_NAME
# Should show role details
```

---

## Security Group

### What It Is

**A security group is a virtual firewall** - it controls which network traffic can reach your server.

**Think of it like:**
- Firewall rules for your server
- What ports/protocols can connect
- From where (IP addresses)

**Why you need it:**
- Only allow necessary ports (22 for SSH, 80 for HTTP, 443 for HTTPS)
- Prevent unauthorized access
- Required by AWS before launching EC2

**Ports explained:**
- **22 (SSH):** Secure remote access (terminal access to server)
- **80 (HTTP):** Web traffic (unencrypted)
- **443 (HTTPS):** Secure web traffic (encrypted)

### Option A: Deploy via Playbook (Automated)

**Recommended**

```bash
cd deployment

# Create security group with rules
ansible-playbook playbooks/create-security-group.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Creates security group named `{app_name}-sg`
- ✅ Opens port 22 (SSH) from anywhere
- ✅ Opens port 80 (HTTP) from anywhere
- ✅ Opens port 443 (HTTPS) from anywhere

**Verify in AWS Console:**
- Go to [Security Groups Console](https://ec2.console.aws.amazon.com/ec2/home#SecurityGroups)
- Search for `{app_name}-sg`
- Click it and view Inbound Rules (should see 3 rules for ports 22, 80, 443)

### Option B: Create Manually via AWS CLI

**Manual control**

```bash
# Set variables
SG_NAME="{app_name}-sg"
SG_DESC="Security group for {app_name}"
AWS_REGION="us-east-2"

# 1. Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "$SG_DESC" \
  --region $AWS_REGION \
  --query 'GroupId' \
  --output text)

echo "Created security group: $SG_ID"

# 2. Add SSH rule (port 22)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION
echo "✅ SSH port 22 opened"

# 3. Add HTTP rule (port 80)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION
echo "✅ HTTP port 80 opened"

# 4. Add HTTPS rule (port 443)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION
echo "✅ HTTPS port 443 opened"

# 5. Verify
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions'
```

---

## SSH Key Pair

### What It Is

**SSH key pair = password-less authentication to your server**

Two parts:
- **Public key:** Stored on server (anyone can know this)
- **Private key:** Stored on your computer (keep secret!)

**How it works:**
1. You send message signed with private key
2. Server verifies with public key
3. Access granted

**Why better than password:**
- Can't be brute-forced
- No password to type (or steal)
- Can revoke access instantly by removing public key

---

### Option A: Deploy via Playbook (Automated)

**Recommended**

```bash
cd deployment

# Create SSH key pair
ansible-playbook playbooks/create-ssh-key.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Generates SSH key pair
- ✅ Saves private key to `~/.ssh/{app_name}-key.pem`
- ✅ Sets correct permissions (600 = read-only by owner)
- ✅ Creates public key on AWS
- ✅ Saves key info to `instance-info.txt`

**Verify:**
```bash
# Check private key exists
ls -la ~/.ssh/{app_name}-key.pem
# Should show: -rw------- (permissions 600)

# Check key size
ssh-keygen -l -f ~/.ssh/{app_name}-key.pem
# Should show 2048-bit or 4096-bit RSA key
```

### Option B: Create Manually via AWS CLI

**Manual control**

```bash
# Set variables
KEY_NAME="{app_name}-key"
AWS_REGION="us-east-2"

# 1. Generate key pair on AWS
aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --region $AWS_REGION \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/$KEY_NAME.pem

# 2. Set correct permissions (read-only by owner)
chmod 400 ~/.ssh/$KEY_NAME.pem

# 3. Verify
ls -la ~/.ssh/$KEY_NAME.pem
# Should show: -rw------- (or -r-------- depending on umask)

# 4. Test key (shows fingerprint)
ssh-keygen -l -f ~/.ssh/$KEY_NAME.pem
```

**⚠️ Important:**
- Save this key securely (password manager, backup, etc.)
- Don't commit to Git
- Can't regenerate if lost (have to replace on server)
- Keep only on trusted computers

---

## EC2 Instance

### What It Is

**EC2 = Elastic Compute Cloud = Virtual server in the cloud**

**Think of it as:**
- Renting a computer from AWS
- Runs 24/7 (you pay for every hour)
- Can shut down when not needed
- Can launch/delete in seconds

**Instance type `t3.micro`:**
- 1 vCPU (1 processor core)
- 1GB RAM
- Good for low-traffic apps
- **Free tier eligible** (750 hours/month free for first 12 months)

### Prerequisites

Before launching EC2, you need:
1. ✅ Security group (created above)
2. ✅ SSH key pair (created above)
3. ✅ IAM role (created above)

### Option A: Deploy via Playbook (Automated)

**Recommended**

```bash
cd deployment

# Launch EC2 instance
ansible-playbook playbooks/launch-ec2-instance.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Finds latest Ubuntu 22.04 LTS AMI
- ✅ Launches EC2 instance (t3.micro)
- ✅ Attaches security group
- ✅ Attaches SSH key
- ✅ Attaches IAM role
- ✅ Waits for instance to start
- ✅ Gets instance IP
- ✅ Saves to `instance-info.txt`

**Duration:** 2-3 minutes

**Verify:**
```bash
# Check instance-info.txt
cat deployment/instance-info.txt

# Or check AWS Console
# Go to EC2 Dashboard → Instances
# You should see your instance running with public IP
```

### Option B: Launch Manually via AWS CLI

**Manual control**

```bash
# Set variables
SG_ID="sg-xxxxxxxxx"          # From security group creation
KEY_NAME="{app_name}-key"     # From key pair creation
INSTANCE_NAME="{app_name}-server"
AWS_REGION="us-east-2"

# 1. Find latest Ubuntu 22.04 LTS AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
          "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region $AWS_REGION)

echo "Using AMI: $AMI_ID"

# 2. Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name={app_name}-ec2-role \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --region $AWS_REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched instance: $INSTANCE_ID"

# 3. Wait for instance to be running (1-2 minutes)
aws ec2 wait instance-running \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION
echo "Instance is running"

# 4. Get instance details
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,InstanceState.Name,LaunchTime]' \
  --output table

# 5. Get public IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $AWS_REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance IP: $INSTANCE_IP"
echo "SSH command: ssh -i ~/.ssh/$KEY_NAME.pem ubuntu@$INSTANCE_IP"
```

**What each component does:**
- **AMI ID:** Template/image of operating system to run
- **Instance Type:** Hardware specs (t3.micro = small, cheap)
- **Key Name:** Which SSH key to allow
- **Security Group:** Which firewall rules apply
- **IAM Instance Profile:** Which permissions the instance has

---

## Verification

### All Infrastructure Created?

```bash
# Check EC2 instance
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]'

# Check security group
aws ec2 describe-security-groups \
  --group-names {app_name}-sg \
  --query 'SecurityGroups[0].[GroupId,IpPermissions]'

# Check IAM role
aws iam get-role --role-name {app_name}-ec2-role

# Check S3 bucket
aws s3 ls | grep {app_name}

# Check SSH key
ls -la ~/.ssh/{app_name}-key.pem
```

**All ✅? Ready to deploy application!**

---

## Next Steps

- **Deploy application on EC2:** → [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md#step-2-deploy-application)
- **All via one command:** → [QUICKSTART.md](QUICKSTART.md)
- **Understand architecture:** → [ARCHITECTURE.md](../reference/ARCHITECTURE.md)

