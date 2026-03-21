# Infrastructure Reference

AWS resource details — S3, IAM, EC2, and Security Groups.

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

S3 (Simple Storage Service) is AWS object storage. The application uses it for images, uploads, and backups. S3 provides versioning (recover deleted files), encryption at rest, and 99.99% availability.

Cost: ~$1–2/month for typical usage (first 5 GB free on free tier).

### Option A: Deploy via Playbook (Automated)

**Recommended - Sets up best practices automatically**

```bash
cd deployment

# Run S3 creation playbook
ansible-playbook playbooks/create-s3-bucket.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Creates S3 bucket with unique name from `group_vars/vault.yml`
- ✅ Enables versioning (recover deleted files)
- ✅ Enables encryption (AES-256)
- ✅ Blocks public access (only authorized access)
- ✅ Saves bucket info to `instances/`

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


### Option C: Create via AWS Console

1. Go to [S3 Console](https://s3.console.aws.amazon.com/s3/)
2. Click **Create bucket**
3. **Bucket name:** Use the same value you set for `s3_bucket_name` in your vault. Must be globally unique.
4. **Region:** Same as `aws_region` in vault.yml (e.g. `us-east-2`)
5. **Block all public access:** Check all 4 boxes
6. Click **Create bucket**
7. Open the bucket, then go to **Properties**:
   - **Bucket Versioning** → Edit → Enable → Save
   - **Default encryption** → Edit → SSE-S3 (AES-256) → Save

The bucket name must match your vault configuration exactly, or the application and decommission playbooks will not find it.

---

## IAM Role

### What It Is

IAM (Identity and Access Management) controls who can do what in AWS. An IAM role grants your EC2 instance permission to access S3, CloudWatch, and Secrets Manager without storing credentials on the server.

If the server is compromised, the role can be revoked instantly. No access keys to steal.

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

### Option C: Create via AWS Console

1. Go to [IAM Roles Console](https://console.aws.amazon.com/iam/home#/roles)
2. Click **Create role**
3. **Trusted entity type:** AWS service
4. **Use case:** EC2
5. Click **Next**
6. Search for and attach these managed policies:
   - `AmazonS3FullAccess`
   - `SecretsManagerReadWrite`
   - `CloudWatchLogsFullAccess`
7. Click **Next**
8. **Role name:** `{app_name}-ec2-role` (must match exactly)
9. Click **Create role**
10. Go back to the role list, open `{app_name}-ec2-role`
11. Note the **Instance profile ARN** — the playbook creates this automatically, but the console does too when you create a role with EC2 as the use case

The role name must be `{app_name}-ec2-role` exactly. The decommission playbook searches for this name to delete inline policies, detach managed policies, remove instance profiles, and delete the role.

---

## Security Group

### What It Is

A security group is a virtual firewall that controls which network traffic can reach your server. It defines which ports accept connections and from which IP addresses.

**Why you need it:**
- Only allow necessary ports (22 for SSH, 80 for HTTP, 443 for HTTPS)
- Prevent unauthorized access
- Required by AWS before launching EC2


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

### Option C: Create via AWS Console

1. Go to [EC2 Console → Security Groups](https://console.aws.amazon.com/ec2/home#SecurityGroups)
2. Click **Create security group**
3. **Security group name:** `{app_name}-sg`
4. **Description:** `Security group for {app_name}`
5. **VPC:** Leave default
6. Under **Inbound rules**, click **Add rule** three times:

| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | `0.0.0.0/0` | SSH access |
| HTTP | 80 | `0.0.0.0/0` | Web traffic |
| HTTPS | 443 | `0.0.0.0/0` | Secure web traffic |

7. Click **Create security group**
8. Note the **Security group ID** (e.g. `sg-0abc123`) — you need it when launching EC2

The name must be `{app_name}-sg` exactly. The decommission playbook searches for this name.

**Ports explained:**
- **22 (SSH):** Remote terminal access to the server
- **80 (HTTP):** Unencrypted web traffic
- **443 (HTTPS):** Encrypted web traffic (used after SSL setup)

---

## SSH Key Pair

### What It Is

An SSH key pair provides password-less authentication to your server. It consists of a private key (stored on your machine) and a public key (stored on the server). The private key must be kept secret.


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
- ✅ Saves key info to `instances/`

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

**Important:**
- Save this key securely. You cannot regenerate it if lost.
- Do not commit to Git.
- Keep only on trusted computers.

### Option C: Create via AWS Console

1. Go to [EC2 Console → Key Pairs](https://console.aws.amazon.com/ec2/home#KeyPairs)
2. Click **Create key pair**
3. **Name:** `{app_name}-key`
4. **Key pair type:** RSA
5. **Private key file format:** `.pem`
6. Click **Create key pair**
7. Your browser downloads `{app_name}-key.pem` automatically
8. Move it to your SSH directory and set permissions:

```bash
mv ~/Downloads/{app_name}-key.pem ~/.ssh/{app_name}-key.pem
chmod 400 ~/.ssh/{app_name}-key.pem
```

The key name must be `{app_name}-key` exactly. The decommission playbook searches for this name to delete the AWS key pair and the local `.pem` file.

---

## EC2 Instance

### What It Is

EC2 (Elastic Compute Cloud) is a virtual server running in AWS. You launch an instance from a machine image (AMI), and it runs 24/7 until you stop or terminate it.

**Instance type `t3.micro`:** 1 vCPU, 1 GB RAM. Suitable for low-traffic applications. Free tier eligible (750 hours/month for the first 12 months).

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
- ✅ Saves to `instances/`

**Duration:** 2-3 minutes

**Verify:**
```bash
# Check instance info
cat deployment/instances/*.txt

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
INSTANCE_NAME="{app_name}"
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

### Option C: Launch via AWS Console

1. Go to [EC2 Console → Instances](https://console.aws.amazon.com/ec2/home#Instances)
2. Click **Launch instances**
3. **Name:** `{app_name}` (must match exactly — the terminate playbook finds instances by this Name tag)
4. **Application and OS Images:** Search for `Ubuntu`, select **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type**, architecture **64-bit (x86)**
5. **Instance type:** `t3.micro` (free tier eligible)
6. **Key pair:** Select `{app_name}-key` from the dropdown
7. **Network settings:** Click **Edit**
   - **Select existing security group:** Choose `{app_name}-sg`
   - **Auto-assign public IP:** Enable
8. **Configure storage:** 20 GB, `gp3`
9. **Advanced details** (expand):
   - **IAM instance profile:** Select `{app_name}-ec2-role`
10. Click **Launch instance**
11. Wait 1–2 minutes, then go to **Instances** and note the **Public IPv4 address**
12. Test SSH access:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_INSTANCE_IP
```

The Name tag must be `{app_name}` exactly (not `{app_name}-server`). The terminate and decommission playbooks search for instances by this tag.

---

## Verification

Run these checks after creating all resources:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values={app_name}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]'

aws ec2 describe-security-groups \
  --group-names {app_name}-sg \
  --query 'SecurityGroups[0].[GroupId,GroupName]'

aws iam get-role --role-name {app_name}-ec2-role \
  --query 'Role.[RoleName,Arn]'

aws s3 ls | grep {app_name}

ls -la ~/.ssh/{app_name}-key.pem
```

Every command should return results. If any fails, revisit the corresponding section above.

---

## Next step

Continue to [Chapter 3: Manual Deployment — Step 6](MANUAL_DEPLOYMENT.md#step-6-deploy-application-to-server) to deploy the application on your new server.

## See also

- [Chapter 2: Quick Start](QUICKSTART.md) — deploy with one command instead
- [Architecture](../reference/ARCHITECTURE.md) — system design overview

