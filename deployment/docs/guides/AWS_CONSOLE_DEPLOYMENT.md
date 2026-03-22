# Chapter 3b: AWS Console Deployment

Deploy every resource using the AWS web console (point and click). This guide covers the same steps as [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) but uses the AWS Console instead of CLI commands or Ansible playbooks.

> **Prerequisite:** Complete [Chapter 1: Prerequisites](PREREQUISITES.md) before starting.

> **Naming matters.** Every resource name in this guide matches what the Ansible playbooks and decommission scripts expect. Use the exact names shown or teardown will not find your resources.

Replace `{app_name}` with the value of `app_name` from your encrypted vault (e.g., `rampe`). Check with: `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | head -5`

---

## Step 1: Create S3 Bucket

S3 stores your application images, uploads, and backups.

1. Open [S3 Console](https://s3.console.aws.amazon.com/s3/home)
2. Click **Create bucket**
3. Configure:

| Setting | Value |
|---------|-------|
| Bucket name | Use the value of `s3_bucket_name` from your vault. To check: `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass \| grep s3_bucket` |
| AWS Region | Same as `aws_region` in vault.yml (e.g., `us-east-2`) |
| Object Ownership | ACLs disabled (recommended) |
| Block all public access | Check all 4 boxes |
| Bucket Versioning | Enable |
| Default encryption | Server-side encryption with Amazon S3 managed keys (SSE-S3) |

4. Click **Create bucket**

### Add tags

1. Open the bucket you just created
2. Go to **Properties** tab
3. Scroll to **Tags** → click **Edit**
4. Add:

| Key | Value |
|-----|-------|
| Application | `{app_name}` |
| Environment | production |
| ManagedBy | Ansible |

5. Click **Save changes**

### Verify

Your bucket should appear in the S3 bucket list. The bucket name must match your `s3_bucket_name` exactly — the application reads this value from AWS Secrets Manager at runtime.

---

## Step 2: Create IAM Role

The IAM role gives your EC2 instance permission to access S3, Secrets Manager, and CloudWatch without storing credentials on the server.

### Create the role

1. Open [IAM Console → Roles](https://console.aws.amazon.com/iam/home#/roles)
2. Click **Create role**
3. Configure:

| Setting | Value |
|---------|-------|
| Trusted entity type | AWS service |
| Use case | EC2 |

4. Click **Next**

### Attach managed policy

5. Search for `AmazonSSMManagedInstanceCore` and check the box
6. Click **Next**
7. Configure:

| Setting | Value |
|---------|-------|
| Role name | `{app_name}-ec2-role` |
| Description | IAM role for {app_name} EC2 instance |

8. Under **Tags**, add:

| Key | Value |
|-----|-------|
| Application | `{app_name}` |
| Environment | production |
| ManagedBy | Ansible |

9. Click **Create role**

### Add inline policies

The role needs three inline policies for S3, Secrets Manager, and CloudWatch access.

**Policy 1: S3 access**

1. Open the role: [IAM → Roles → `{app_name}-ec2-role`](https://console.aws.amazon.com/iam/home#/roles)
2. Click **Add permissions** → **Create inline policy**
3. Click the **JSON** tab
4. Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME",
        "arn:aws:s3:::YOUR_BUCKET_NAME/*"
      ]
    }
  ]
}
```

Replace `YOUR_BUCKET_NAME` with your `s3_bucket_name` value.

5. Click **Next**
6. **Policy name:** `{app_name}-s3-access`
7. Click **Create policy**

**Policy 2: Secrets Manager access**

1. Click **Add permissions** → **Create inline policy** → **JSON** tab
2. Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-2:*:secret:{app_name}/*"
    }
  ]
}
```

Replace `us-east-2` with your `aws_region` and `{app_name}` with your application name.

3. **Policy name:** `{app_name}-secrets-access`
4. Click **Create policy**

**Policy 3: CloudWatch access**

1. Click **Add permissions** → **Create inline policy** → **JSON** tab
2. Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```

3. **Policy name:** `{app_name}-cloudwatch-access`
4. Click **Create policy**

### Create instance profile

When you create a role with the EC2 use case, AWS auto-creates an instance profile with the same name as the role. The Ansible playbooks use a separate profile named `{app_name}-instance-profile`. To match, run this CLI command:

```bash
aws iam create-instance-profile --instance-profile-name {app_name}-instance-profile
aws iam add-role-to-instance-profile \
  --role-name {app_name}-ec2-role \
  --instance-profile-name {app_name}-instance-profile
```

Alternatively, when launching EC2 in Step 5, select `{app_name}-ec2-role` from the dropdown (uses the auto-created profile).

### Verify

Go to [IAM → Roles](https://console.aws.amazon.com/iam/home#/roles), open `{app_name}-ec2-role`. Under **Permissions** you should see:

- `AmazonSSMManagedInstanceCore` (managed)
- `{app_name}-s3-access` (inline)
- `{app_name}-secrets-access` (inline)
- `{app_name}-cloudwatch-access` (inline)

---

## Step 3: Create Security Group

The security group controls which network traffic can reach your server.

1. Open [EC2 Console → Security Groups](https://console.aws.amazon.com/ec2/home#SecurityGroups)
2. Click **Create security group**
3. Configure:

| Setting | Value |
|---------|-------|
| Security group name | `{app_name}-sg` |
| Description | Security group for {app_name} |
| VPC | Leave default |

4. Under **Inbound rules**, click **Add rule** three times:

| Type | Port range | Source | Description |
|------|-----------|--------|-------------|
| SSH | 22 | `0.0.0.0/0` | SSH access |
| HTTP | 80 | `0.0.0.0/0` | Web traffic |
| HTTPS | 443 | `0.0.0.0/0` | Secure web traffic |

5. Leave **Outbound rules** as default (all traffic allowed)
6. Under **Tags**, add:

| Key | Value |
|-----|-------|
| Name | `{app_name}-sg` |
| Application | `{app_name}` |

7. Click **Create security group**
8. Note the **Security group ID** (e.g., `sg-0abc123def456`) — you need it in Step 5

### Verify

The security group appears in the list. Click it and confirm three inbound rules for ports 22, 80, and 443.

---

## Step 4: Create SSH Key Pair

The SSH key pair provides password-less authentication to your server.

1. Open [EC2 Console → Key Pairs](https://console.aws.amazon.com/ec2/home#KeyPairs)
2. Click **Create key pair**
3. Configure:

| Setting | Value |
|---------|-------|
| Name | `{app_name}-key` |
| Key pair type | RSA |
| Private key file format | `.pem` |

4. Under **Tags**, add:

| Key | Value |
|-----|-------|
| Application | `{app_name}` |

5. Click **Create key pair**
6. Your browser downloads `{app_name}-key.pem` automatically

### Secure the private key

```bash
mv ~/Downloads/{app_name}-key.pem ~/.ssh/{app_name}-key.pem
chmod 400 ~/.ssh/{app_name}-key.pem
```

This key cannot be downloaded again. If you lose it, you must create a new key pair.

### Verify

```bash
ls -la ~/.ssh/{app_name}-key.pem
# Should show: -r-------- (permissions 400)
```

---

## Step 5: Launch EC2 Instance

Create the virtual server that runs your application.

1. Open [EC2 Console → Instances](https://console.aws.amazon.com/ec2/home#Instances)
2. Click **Launch instances**

### Name and AMI

| Setting | Value |
|---------|-------|
| Name | `{app_name}` |
| Application and OS Images | Search `Ubuntu`, select **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type** |
| Architecture | 64-bit (x86) |

The Name tag must be exactly `{app_name}` (not `{app_name}-server`). The terminate and decommission playbooks find instances by this tag.

### Instance type

| Setting | Value |
|---------|-------|
| Instance type | `t3.micro` (free tier eligible) |

### Key pair

| Setting | Value |
|---------|-------|
| Key pair name | Select `{app_name}-key` from the dropdown |

### Network settings

Click **Edit**, then:

| Setting | Value |
|---------|-------|
| VPC | Default |
| Subnet | No preference |
| Auto-assign public IP | **Enable** |
| Firewall (security groups) | Select existing security group |
| Security group | Select `{app_name}-sg` |

### Configure storage

| Device | Size | Type | Encrypted |
|--------|------|------|-----------|
| Root volume (`/dev/xvda`) | 20 GB | gp3 | Yes |
| Data volume (`/dev/sdf`) | 100 GB (or your `ebs_volume_size`) | gp3 | Yes |

Click **Add new volume** to add the data volume.

### Advanced details

Expand **Advanced details**:

| Setting | Value |
|---------|-------|
| IAM instance profile | Select `{app_name}-ec2-role` (or `{app_name}-instance-profile`) |
| Detailed CloudWatch monitoring | Enable (optional) |
| Termination protection | Disable (enable later for production) |

### Launch

1. Click **Launch instance**
2. Wait 1–2 minutes for the instance to start
3. Go to **Instances**, find your instance
4. Note the **Public IPv4 address**

### Verify

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_PUBLIC_IP
# You should see the Ubuntu welcome message
exit
```

---

## Step 6: Deploy Application to Server

The console cannot deploy application code. Use one of these options:

**Option A: Ansible playbook (recommended)**

If you launched via the console (not the playbook), update the inventory first:

```bash
cd deployment
# Set your server IP in the inventory
sed -i.bak "s/ansible_host:.*/ansible_host: YOUR_PUBLIC_IP/" inventories/hosts.yml
sed -i.bak "s/ansible_connection:.*/ansible_connection: ssh/" inventories/hosts.yml

# Deploy
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
```

**Option B: SSH manual setup**

See [Chapter 3: Manual Deployment — Step 6b](MANUAL_DEPLOYMENT.md#step-6b-deploy-via-ssh-manual).

### Verify

```bash
curl http://YOUR_PUBLIC_IP
# Should return your application homepage
```

---

## Step 7: Configure SSL/HTTPS

SSL is required for all production deployments. If you deployed with `setup.yml`, the certificate was installed automatically. If not, follow these steps.

SSL requires a custom domain pointed at your server.

### Point your domain to the server

Go to your domain registrar and create an **A record**:

| Type | Name | Value |
|------|------|-------|
| A | `@` (or subdomain) | YOUR_PUBLIC_IP |

Wait for DNS propagation (1–5 minutes, can take up to 48 hours).

### Install SSL certificate

There is no console-only way to install Let's Encrypt. SSH to the server:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_PUBLIC_IP

sudo apt update
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email your@email.com \
  --domains your-domain.com \
  --redirect

exit
```

Or use the playbook:

```bash
ansible-playbook playbooks/setup-ssl.yml --vault-password-file ~/.vault_pass
```

### Verify

Open `https://your-domain.com` in a browser. The padlock icon should appear.

---

## Step 8: Set Up Monitoring (Optional)

### Install the CloudWatch agent

Use the playbook (no console-only method for agent install):

```bash
ansible-playbook playbooks/setup-monitoring.yml --vault-password-file ~/.vault_pass
```

### Create alarms in the console

1. Open [CloudWatch → Alarms](https://console.aws.amazon.com/cloudwatch/home#alarmsV2:)
2. Click **Create alarm** → **Select metric**
3. Choose **EC2** → **Per-Instance Metrics**
4. Find your instance, select `CPUUtilization`
5. Configure:

| Setting | Value |
|---------|-------|
| Statistic | Average |
| Period | 5 minutes |
| Threshold type | Static |
| Condition | Greater than 80 |
| Datapoints to alarm | 1 out of 1 |

6. **Notification:** Create or select an SNS topic, enter your email
7. **Alarm name:** `{app_name}-cpu-high`
8. Click **Create alarm**

### View logs in the console

1. Open [CloudWatch → Log groups](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups)
2. Look for log groups starting with `/{app_name}/`
3. Click a log group to view log streams

See [Chapter 6: Monitoring](MONITORING.md) for the full alarm and dashboard setup.

---

## Step 9: Create Secrets in Secrets Manager (Optional)

### Create the secret via console

1. Open [Secrets Manager](https://console.aws.amazon.com/secretsmanager/listsecrets)
2. Click **Store a new secret**
3. **Secret type:** Other type of secret
4. Under **Key/value pairs**, add each secret:

| Key | Value |
|-----|-------|
| `SECRET_KEY` | Your Flask secret key |
| `USERS` | `username:password` |
| `S3_BUCKET` | Your S3 bucket name |
| `AWS_DEFAULT_REGION` | Your AWS region (e.g., `us-east-2`) |

Add any additional secrets (eBay API keys, etc.).

5. Click **Next**
6. **Secret name:** `{app_name}/app-secrets`
7. Under **Tags**, add:

| Key | Value |
|-----|-------|
| Application | `{app_name}` |
| ManagedBy | Ansible |

8. Click **Next** → **Next** → **Store**

Or use the playbook (recommended — reads from your encrypted vault):

```bash
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass
```

### Verify

Go to [Secrets Manager](https://console.aws.amazon.com/secretsmanager/listsecrets) and confirm `{app_name}/app-secrets` exists.

---

## Verification Checklist

| Resource | Console location | What to look for |
|----------|-----------------|-----------------|
| S3 Bucket | [S3](https://s3.console.aws.amazon.com/s3/) | Bucket with your `s3_bucket_name` |
| IAM Role | [IAM → Roles](https://console.aws.amazon.com/iam/home#/roles) | `{app_name}-ec2-role` with 4 policies |
| Security Group | [EC2 → Security Groups](https://console.aws.amazon.com/ec2/home#SecurityGroups) | `{app_name}-sg` with ports 22, 80, 443 |
| SSH Key Pair | [EC2 → Key Pairs](https://console.aws.amazon.com/ec2/home#KeyPairs) | `{app_name}-key` |
| EC2 Instance | [EC2 → Instances](https://console.aws.amazon.com/ec2/home#Instances) | `{app_name}` running with public IP |
| Application | Browser | `http://YOUR_PUBLIC_IP` loads the app |
| Secrets | [Secrets Manager](https://console.aws.amazon.com/secretsmanager/) | `{app_name}/app-secrets` |

---

## Teardown via Console

Delete resources in reverse order. See [Chapter 13: Decommission](DECOMMISSION.md) for the full guide.

| Order | Resource | Console location | Action |
|-------|----------|-----------------|--------|
| 1 | EC2 Instance | [Instances](https://console.aws.amazon.com/ec2/home#Instances) | Select → Instance state → **Terminate instance** |
| 2 | Security Group | [Security Groups](https://console.aws.amazon.com/ec2/home#SecurityGroups) | Select `{app_name}-sg` → Actions → **Delete** (wait for instance to terminate first) |
| 3 | SSH Key Pair | [Key Pairs](https://console.aws.amazon.com/ec2/home#KeyPairs) | Select `{app_name}-key` → Actions → **Delete** |
| 4 | IAM Role | [IAM → Roles](https://console.aws.amazon.com/iam/home#/roles) | Open `{app_name}-ec2-role` → delete inline policies first → then **Delete** role |
| 5 | S3 Bucket | [S3](https://s3.console.aws.amazon.com/s3/) | Select bucket → **Empty** first → then **Delete** |
| 6 | Secrets | [Secrets Manager](https://console.aws.amazon.com/secretsmanager/) | Select `{app_name}/app-secrets` → Actions → **Delete secret** |
| 7 | Local key | Terminal | `rm ~/.ssh/{app_name}-key.pem` |

Or use the automated teardown:

```bash
ansible-playbook playbooks/decommission.yml --vault-password-file ~/.vault_pass
```

---

## Next step

Continue to [Chapter 4: Updating Your Application](UPDATING_APPLICATION.md).

## See also

- [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) — CLI and Playbook versions of the same steps
- [Infrastructure Reference](INFRASTRUCTURE.md) — what each AWS resource does
- [Chapter 13: Decommission](DECOMMISSION.md) — full teardown guide
