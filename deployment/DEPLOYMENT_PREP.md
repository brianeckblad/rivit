# Deployment Preparation & Reference

**Version:** 5.0  
**Date:** February 8, 2026

---

## 🎯 Application Configuration

### App Identity & Naming

**Before starting deployment**, configure your application name and URL in:

**File:** `deployment/group_vars/all.yml`

```yaml
# ============================================================================
# Application Identity - CHANGE THESE TO RENAME YOUR APP
# ============================================================================
app_name: app_item_listing_tool              # Technical name (paths, services)
app_display_name: "App Item Listing Tool"    # Human-readable name (docs, UI)
app_url: "https://github.com/yourusername/app_item_listing_tool"
```

**To rename your app:**
1. Edit `deployment/group_vars/all.yml`
2. Change `app_name` to your new name (e.g., `katlo`, `listkit`)
3. Change `app_display_name` to display name
4. Update `app_url` to your GitHub repository
5. **Important:** Use lowercase, underscores only for `app_name`

**Example rename:**
```yaml
app_name: katlo
app_display_name: "Katlo"
app_url: "https://github.com/yourusername/katlo"
```

**What gets renamed automatically:**
- Service names (systemd/supervisor)
- Log directories (`/var/log/katlo`)
- Application paths (`/home/ubuntu/katlo`)
- Configuration files
- AWS resource tags

**One change updates everything!** ✨

---

## 📋 Pre-Deployment Checklist

### Before You Start

- [ ] AWS account created and verified
- [ ] Domain name registered (if using custom domain)
- [ ] eBay developer account created
- [ ] GitHub repository set up
- [ ] Local development environment working

### Tools Installation

```bash
# Check Python version (3.8+ required)
python3 --version

# Install AWS CLI
pip install awscli boto3

# Install jq
brew install jq  # macOS
sudo apt-get install jq  # Ubuntu

# Install Ansible
pip install ansible

# Verify installations
aws --version
jq --version
ansible --version
```

### AWS Account Setup

#### Create IAM User for Deployment

1. Go to AWS Console → IAM → Users → Add User
2. **Username:** `deployment-user`
3. **Access type:** Programmatic access
4. **Permissions:** Attach `AdministratorAccess` (for initial setup)
5. **Save credentials:**
   - Access Key ID
   - Secret Access Key

**Note:** These credentials are ONLY for running the deployment scripts. The EC2 instance will use IAM roles (no credentials needed on server).

#### IAM Roles (Automated)

The deployment script automatically creates an IAM role for your EC2 instance with:
- **S3 Access** - Read/write to your bucket (least privilege)
- **Secrets Manager Access** - Read secrets (no AWS credentials needed on server)
- **SSM Session Manager** - Secure access without SSH keys

**No action needed** - the `infra-complete-setup.sh` script creates this automatically.

**⚠️ After deployment:** Create least-privilege policy and remove AdministratorAccess

#### Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-east-1
# Default output format: json

# Test configuration
aws sts get-caller-identity
```

---

## 🔑 Credentials Management

### eBay Developer Account

#### Create Sandbox Account (Testing)

1. Go to: https://developer.ebay.com
2. Register for developer account
3. Create application (Sandbox)
4. Note credentials:
   - Sandbox App ID (Client ID)
   - Sandbox Dev ID
   - Sandbox Cert ID (Client Secret)

#### Create Production Account

1. Same developer portal
2. Create production application
3. Complete certification process
4. Note credentials:
   - Production App ID
   - Production Dev ID
   - Production Cert ID

#### Generate OAuth Token

```bash
# Use the provided script
cd deployment/scripts
./generate-ebay-token.sh

# Or use eBay's token generator:
# https://developer.ebay.com/my/auth/?env=production&index=0
```

### GitHub Personal Access Token

#### Create Token with Minimal Permissions

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. **Name:** `deployment-token`
4. **Expiration:** 90 days (or custom)
5. **Select scopes:**
   - ✅ `repo` (required for cloning)
     - ✅ `repo:status`
     - ✅ `repo_deployment`  
     - ✅ `public_repo` (if public repo)
   - ❌ NO admin scopes
   - ❌ NO delete scopes
   - ❌ NO user scopes
   - ❌ NO org scopes
6. Generate and save token (starts with `ghp_`)

**⚠️ Security:** This token can only clone/pull your repository, nothing else!

### Generate Application Secrets

```bash
# SECRET_KEY (Flask session encryption)
python3 -c "import secrets; print(secrets.token_hex(32))"
# Example: a1b2c3d4e5f6...

# APP_SECRET_TOKEN (API access token)
python3 -c "import secrets; print(secrets.token_hex(16))"
# Example: f1e2d3c4...
```

---

## 📝 Secrets File Template

Create `secrets.env` in the deployment directory:

```bash
cat > deployment/secrets.env << 'EOF'
# ============================================
# AWS Secrets
# ============================================
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-unique-bucket-name

# ============================================
# Application Secrets
# ============================================
SECRET_KEY=your-64-char-hex-secret-here
APP_SECRET_TOKEN=your-32-char-hex-token-here

# ============================================
# eBay Production Credentials
# ============================================
EBAY_PRODUCTION_APP_ID=YourApp-YourApp-PRD-1234567890-a1b2c3d4
EBAY_PRODUCTION_DEV_ID=a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890
EBAY_PRODUCTION_CERT_ID=PRD-1234567890ab-cdef-1234-5678-90ab
EBAY_PRODUCTION_TOKEN=v^1.1#i^1#...long-token-here

# ============================================
# eBay Sandbox Credentials (Optional)
# ============================================
EBAY_SANDBOX_APP_ID=YourApp-YourApp-SBX-1234567890-a1b2c3d4
EBAY_SANDBOX_DEV_ID=a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890
EBAY_SANDBOX_CERT_ID=SBX-1234567890ab-cdef-1234-5678-90ab
EBAY_SANDBOX_TOKEN=v^1.1#i^1#...sandbox-token-here

# ============================================
# Admin Credentials
# ============================================
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-admin-password-here

# ============================================
# GitHub Deployment
# ============================================
GITHUB_TOKEN=ghp_your_personal_access_token_here
GITHUB_REPO=yourusername/app_item_listing_tool
GITHUB_BRANCH=main

# ============================================
# CloudFront (auto-generated during setup)
# ============================================
# CLOUDFRONT_DOMAIN=d123456abcdef.cloudfront.net
# CLOUDFRONT_DISTRIBUTION_ID=E123456EXAMPLE

# ============================================
# Optional Settings
# ============================================
# COMICS_PER_PAGE=20
# SESSION_LIFETIME_HOURS=24
EOF

chmod 600 deployment/secrets.env
```

**⚠️ Security:** 
- Never commit `secrets.env` to git!
- Add to `.gitignore`
- Store backup in password manager

---

## 🏗️ Infrastructure Specifications

### EC2 Instance Options

| Instance Type | vCPU | RAM | Cost/Month | Best For |
|--------------|------|-----|------------|----------|
| t3.nano | 2 | 0.5 GB | $3.80 | Testing |
| t3.micro ⭐ | 2 | 1 GB | $7.59 | **Recommended** |
| t3.small | 2 | 2 GB | $15.18 | High traffic |
| t4g.nano (ARM) | 2 | 0.5 GB | $3.07 | Budget |
| t4g.micro (ARM) | 2 | 1 GB | $6.13 | Best value |

**Reserved instances save 50%:** 
- t3.micro reserved (1yr): $3.80/month
- t4g.micro reserved (1yr): $3.07/month

### Storage Sizing

**EC2 Root Volume:**
- 20 GB (standard)
- gp3 SSD
- Cost: ~$2/month

**S3 Bucket:**
- Pay per GB stored
- $0.023/GB/month
- Estimated: 50-200 GB = $1-5/month

### CloudFront Configuration

**Price Class Options:**
- `PriceClass_100` - US, Canada, Europe ($5-10/month)
- `PriceClass_200` - Above + Asia, South America ($10-15/month)
- `PriceClass_All` - All edge locations ($15-20/month)

**Recommended:** PriceClass_100 (covers most traffic, lowest cost)

**Free Tier:**
- 1 TB data transfer out/month
- 10,000,000 HTTP/HTTPS requests
- 2,000,000 CloudFront Function invocations

### WAF Configuration

**Managed Rule Groups (Recommended):**
- AWS Core Rule Set - $2/month
- Known Bad Inputs - $2/month  
- SQL Injection - $2/month
- Rate-Based Rule - $1/month

**Custom Rules:**
- $1/rule/month

**Requests:**
- $0.60 per 1 million requests

**Estimated Total:** $8-15/month

---

## 🌐 DNS Configuration

### CloudFront Distribution

After deployment, you'll receive a CloudFront domain:
```
d123456abcdef.cloudfront.net
```

### DNS Records to Create

#### Option A: Root Domain (example.com)

```
Type:  A + AAAA (Alias)
Name:  @
Value: d123456abcdef.cloudfront.net
TTL:   300
```

**Note:** Not all DNS providers support ALIAS for root domain. You may need to use CNAME with www subdomain.

#### Option B: Subdomain (app.example.com)

```
Type:  CNAME
Name:  app
Value: d123456abcdef.cloudfront.net
TTL:   300
```

#### Option C: Both (with www redirect)

```
# Main domain
Type:  CNAME
Name:  www
Value: d123456abcdef.cloudfront.net

# Redirect root to www
Type:  A
Name:  @
Value: [URL redirect to www.example.com]
```

### DNS Providers Instructions

**Cloudflare:**
1. DNS → Add record → CNAME
2. Name: `app` (or `www`)
3. Target: CloudFront domain
4. Proxy status: DNS only (grey cloud) ⚠️
5. TTL: Auto

**Route 53 (AWS):**
```bash
# Create hosted zone
aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)

# Create CNAME record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456EXAMPLE \
  --change-batch file://dns-record.json
```

**Namecheap:**
1. Domain List → Manage → Advanced DNS
2. Add New Record → CNAME Record
3. Host: `app`
4. Value: CloudFront domain
5. TTL: Automatic

**GoDaddy:**
1. DNS → Records → Add
2. Type: CNAME
3. Name: `app`
4. Value: CloudFront domain
5. TTL: 600

---

## 🔒 Security Best Practices

### Secrets Manager Access

**IAM Policy for EC2:**
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
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:*:secret:app-item-listing-tool/*"
      ]
    }
  ]
}
```

### S3 Bucket Policy

**Restrict to EC2 IAM role only:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEC2RoleAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:role/app-item-listing-tool-ec2-role"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

### CloudFront Security Headers

Automatically configured via deployment:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

### Rate Limiting Strategy

**WAF Rate Limits:**
- Global: 2000 requests per 5 minutes per IP
- Login endpoint: 10 requests per minute per IP
- API endpoints: 100 requests per minute per IP

**Fail2ban (Backup):**
- SSH: 5 failed attempts = 1 hour ban
- HTTP: 20x 4xx errors in 10 min = 30 min ban

---

## 📊 Monitoring Setup

### CloudWatch Metrics

**Automatically tracked:**
- CloudFront: Requests, errors, cache hit rate
- WAF: Allowed/blocked requests
- EC2: CPU, memory, disk, network
- Application: Custom metrics via SDK

### Alarms Configuration

```bash
# Email for alerts
YOUR_EMAIL=your-email@example.com

# Setup alarms
./scripts/cloudwatch-alarms-setup.sh $YOUR_EMAIL
```

**Alarms created:**
1. **HighErrorRate:** 5xx errors > 5% for 10 minutes
2. **HighRequestRate:** Requests > 10,000/minute
3. **WAFBlockSpike:** Blocked requests > 100/minute
4. **EC2HighCPU:** CPU > 80% for 15 minutes
5. **EC2HighMemory:** Memory > 90% for 10 minutes
6. **DiskSpacelow:** Disk > 85% full

### Log Locations

**On EC2:**
```
/var/log/app_item_listing_tool/
├── access.log      # Nginx access logs
├── error.log       # Application errors
├── gunicorn.log    # WSGI server logs
└── security.log    # Security events
```

**In CloudWatch Logs:**
```
/aws/cloudfront/app-item-listing-tool   # CloudFront logs
/aws/waf/app-item-listing-tool          # WAF logs
/aws/ec2/app-item-listing-tool          # System logs
```

**In S3:**
```
s3://your-bucket-name/logs/
├── cloudfront/     # CloudFront access logs
├── waf/           # WAF detailed logs
└── application/   # Application backups
```

---

## 🔄 Backup & Recovery

### Automated Backups

**Configured automatically:**
- Instance snapshots: Daily at 2 AM UTC
- S3 sync: Every 15 minutes
- Database exports: Daily at 3 AM UTC
- Log rotation: Weekly

### Manual Backup

```bash
# Connect to instance
aws ssm start-session --target i-xxxxxxxxxxxxx

# Backup everything
sudo /opt/app-scripts/backup-all.sh

# Backup to S3
aws s3 sync /home/ubuntu/app_item_listing_tool/instance \
  s3://your-bucket-name/backups/manual/$(date +%Y%m%d)/
```

### Recovery Procedure

**From S3 backup:**
```bash
# 1. List available backups
aws s3 ls s3://your-bucket-name/backups/ --recursive

# 2. Restore specific backup
aws s3 sync \
  s3://your-bucket-name/backups/20260208/ \
  /home/ubuntu/app_item_listing_tool/instance/

# 3. Restart application
sudo systemctl restart app_item_listing_tool
```

**From EC2 snapshot:**
```bash
# 1. List snapshots
aws ec2 describe-snapshots --owner-ids self

# 2. Create new volume from snapshot
aws ec2 create-volume \
  --snapshot-id snap-1234567890abcdef0 \
  --availability-zone us-east-1a

# 3. Attach to instance
aws ec2 attach-volume \
  --volume-id vol-1234567890abcdef0 \
  --instance-id i-xxxxxxxxxxxxx \
  --device /dev/sdf

# 4. Mount and restore
```

---

## 📞 Support Resources

### AWS Documentation

- [EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [CloudFront Developer Guide](https://docs.aws.amazon.com/cloudfront/)
- [WAF Developer Guide](https://docs.aws.amazon.com/waf/)
- [Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/)
- [Systems Manager User Guide](https://docs.aws.amazon.com/systems-manager/)

### Cost Calculators

- [AWS Pricing Calculator](https://calculator.aws/)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [WAF Pricing](https://aws.amazon.com/waf/pricing/)

### Testing Tools

- [SSL Labs](https://www.ssllabs.com/ssltest/) - Test SSL configuration
- [Security Headers](https://securityheaders.com/) - Test security headers
- [WebPageTest](https://www.webpagetest.org/) - Performance testing
- [GTmetrix](https://gtmetrix.com/) - Page speed insights

---

## ✅ Final Checklist

Before running deployment:

### Credentials
- [ ] AWS access keys configured
- [ ] eBay API credentials obtained
- [ ] GitHub token created (repo scope only)
- [ ] Admin password chosen
- [ ] All secrets in `secrets.env` file

### Infrastructure
- [ ] AWS account has sufficient limits
- [ ] Domain name ready (optional)
- [ ] DNS provider accessible
- [ ] Email for alerts configured

### Local Environment
- [ ] AWS CLI installed and configured
- [ ] jq installed
- [ ] Ansible installed
- [ ] Python 3.8+ available
- [ ] Git repository cloned

### Documentation
- [ ] Read complete deployment guide
- [ ] Understand architecture
- [ ] Know how to access logs
- [ ] Backup plan understood

---

**Ready to deploy?** → See `DEPLOYMENT_COMPLETE_GUIDE.md`

**Version:** 5.0  
**Last Updated:** February 8, 2026

