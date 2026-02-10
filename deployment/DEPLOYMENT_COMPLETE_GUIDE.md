# Complete Deployment Guide

**Version:** 5.0  
**Date:** February 8, 2026  
**Architecture:** EC2 + CloudFront + WAF + SSM + AWS Secrets Manager

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start (Automated)](#quick-start-automated)
4. [Manual Deployment](#manual-deployment)
5. [Post-Deployment](#post-deployment)
6. [Troubleshooting](#troubleshooting)
7. [Architecture](#architecture)

---

## Overview

### What Gets Deployed

This deployment creates a **production-grade, secure, DDoS-protected** infrastructure:

```
User → CloudFront (CDN + DDoS Protection)
  ↓
WAF (Web Application Firewall)
  ↓
EC2 Instance (t3.nano, Ubuntu 22.04)
  ↓
Application (Flask + Gunicorn + Nginx)
  ↓
AWS Secrets Manager (All credentials)
  ↓
S3 (Image storage)
```

### Key Features

- ✅ **CloudFront CDN** - DDoS protection, caching, global edge locations
- ✅ **AWS WAF** - Layer 7 protection, rate limiting, bot detection
- ✅ **AWS Secrets Manager** - No credentials on server, automatic rotation
- ✅ **SSM Session Manager** - No SSH keys, no port 22 exposed
- ✅ **EC2 with IAM Roles** - No hardcoded AWS credentials
- ✅ **Automated Security** - UFW, Fail2ban, auto-updates
- ✅ **SSL/TLS** - Free Let's Encrypt certificates

### Cost Estimate

```
EC2 t3.nano:        $3.80/month (or $1.90 reserved)
S3 Storage:         $1-2/month
CloudFront:         $5-10/month (1TB free/month)
WAF:                $5-10/month
Secrets Manager:    $0.40/secret/month (~$4/month total)
CloudWatch:         $1-2/month
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total:              $20-30/month
```

---

## Prerequisites

### Required Tools (Local Machine)

```bash
# AWS CLI
pip install awscli boto3

# jq (JSON processor)
brew install jq  # macOS
sudo apt-get install jq  # Ubuntu

# Ansible
pip install ansible

# Python 3.8+
python --version
```

### Required AWS Permissions

Your AWS IAM user needs these permissions:
- `ec2:*` (EC2 full access)
- `s3:*` (S3 full access)
- `iam:*` (IAM full access)
- `cloudfront:*` (CloudFront full access)
- `wafv2:*` (WAF full access)
- `secretsmanager:*` (Secrets Manager full access)
- `ssm:*` (Systems Manager full access)

**Recommended:** Use `AdministratorAccess` policy for initial setup, then create least-privilege policy after deployment.

### Required Credentials

Gather these before starting:

**AWS:**
- [ ] AWS Access Key ID
- [ ] AWS Secret Access Key
- [ ] AWS Region (default: us-east-1)
- [ ] S3 Bucket Name (globally unique)

**eBay API:**
- [ ] Production App ID
- [ ] Production Dev ID
- [ ] Production Cert ID
- [ ] Production Token (or generate via script)

**Application:**
- [ ] Admin Username
- [ ] Admin Password
- [ ] Domain Name (for SSL)

**GitHub (for deployment):**
- [ ] Personal Access Token with `repo` scope only

### GitHub Token Security

**Minimal Required Permissions:**
```
✅ repo (required for cloning)
  ✅ repo:status
  ✅ repo_deployment
  ✅ public_repo

❌ NOT NEEDED:
  ❌ admin:org
  ❌ delete_repo
  ❌ user
  ❌ admin:repo_hook
```

**Create token:** GitHub → Settings → Developer settings → Personal access tokens → Generate new token (classic)

---

## Quick Start (Automated)

### Step 1: Prepare Secrets File

Create a local secrets file (never commit this!):

```bash
cd deployment
cat > secrets.env << 'EOF'
# Application Secrets
SECRET_KEY=your-secret-key-here

# eBay Production
EBAY_PRODUCTION_APP_ID=your-app-id
EBAY_PRODUCTION_DEV_ID=your-dev-id
EBAY_PRODUCTION_CERT_ID=your-cert-id
EBAY_PRODUCTION_TOKEN=your-token

# eBay Sandbox (optional)
EBAY_SANDBOX_APP_ID=sandbox-app-id
EBAY_SANDBOX_DEV_ID=sandbox-dev-id
EBAY_SANDBOX_CERT_ID=sandbox-cert-id
EBAY_SANDBOX_TOKEN=sandbox-token

# Admin Credentials
ADMIN_USERNAME=admin
ADMIN_PASSWORD=secure-password-here

# GitHub (for deployment)
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPO=yourusername/app_item_listing_tool

# Application
APP_SECRET_TOKEN=generate-random-token
EOF

chmod 600 secrets.env
```

**Generate secure values:**
```bash
# SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"

# APP_SECRET_TOKEN
python3 -c "import secrets; print(secrets.token_hex(16))"
```

### Step 2: Run Complete Setup

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

**The script will:**
1. ✅ Verify AWS credentials
2. ✅ Create VPC and networking
3. ✅ Launch EC2 instance (t3.nano)
4. ✅ Create and configure S3 bucket
5. ✅ Upload secrets to AWS Secrets Manager
6. ✅ Create CloudFront distribution
7. ✅ Configure AWS WAF with rate limiting
8. ✅ Setup SSM Session Manager
9. ✅ Deploy application
10. ✅ Configure SSL certificate

**Duration:** 10-15 minutes

### Step 3: Update DNS

After setup completes, update your DNS:

```
Type: CNAME
Name: yourdomain.com (or subdomain)
Value: d123456abcdef.cloudfront.net
TTL: 300
```

**Wait for DNS propagation** (5-30 minutes)

### Step 4: Verify Deployment

```bash
# Check CloudFront distribution
curl -I https://your-cloudfront-domain.cloudfront.net

# Check application
curl https://yourdomain.com

# Test SSM connectivity
aws ssm start-session --target i-xxxxxxxxxxxxx
```

---

## Manual Deployment

If you prefer step-by-step control, follow these manual steps:

### Phase 1: AWS Infrastructure

#### 1.1: Create EC2 Infrastructure

```bash
cd deployment
./scripts/aws-setup.sh
```

Prompts:
- AWS credentials
- S3 bucket name
- EC2 instance type (recommend: t3.nano)
- Enable SSM? (yes)

**Output:** EC2 instance ID, IP address, VPC details

#### 1.2: Upload Secrets to AWS Secrets Manager

```bash
# Create secrets from secrets.env file
./scripts/secrets-manager-setup.sh secrets.env
```

This creates secret: `app-item-listing-tool/production` with all environment variables.

**Verify:**
```bash
aws secretsmanager list-secrets
aws secretsmanager get-secret-value --secret-id app-item-listing-tool/production
```

#### 1.3: Update Application to Use Secrets Manager

```bash
# Application will automatically fetch from Secrets Manager on startup
# No .env file needed on server!
```

### Phase 2: CloudFront + WAF

#### 2.1: Create CloudFront Distribution

```bash
./scripts/cloudfront-setup.sh
```

Prompts:
- EC2 IP address (origin)
- Domain names (optional)
- Price class (recommend: US/Canada/Europe)

**Output:** CloudFront distribution ID and domain

#### 2.2: Configure AWS WAF

```bash
./scripts/waf-setup.sh
```

Creates WAF Web ACL with:
- ✅ AWS Managed Core Rule Set
- ✅ Rate limiting (2000 req/5min per IP)
- ✅ Known bad inputs protection
- ✅ SQL injection protection
- ✅ XSS protection

**Output:** WAF Web ACL ID

#### 2.3: Associate WAF with CloudFront

```bash
./scripts/waf-associate.sh <cloudfront-distribution-id> <waf-web-acl-id>
```

### Phase 3: Application Deployment

#### 3.1: Deploy Application

```bash
cd deployment
./scripts/app-deploy.sh setup
```

This:
- ✅ Connects via SSM (no SSH needed)
- ✅ Clones repository
- ✅ Installs Python dependencies
- ✅ Configures Nginx
- ✅ Sets up systemd service
- ✅ Starts application

#### 3.2: Configure Origin to Accept CloudFront Only

The application automatically configures Nginx to only accept traffic from CloudFront:

```nginx
# Only allow CloudFront IP ranges
# Blocks direct IP access
```

### Phase 4: SSL Certificate

#### 4.1: Update DNS to CloudFront

First, point your domain to CloudFront (CNAME record).

#### 4.2: Request SSL Certificate

```bash
# Connect via SSM
aws ssm start-session --target i-xxxxxxxxxxxxx

# Request certificate
sudo certbot --nginx -d yourdomain.com
```

**Or use CloudFront certificate** (recommended):
- AWS Console → CloudFront → Distribution
- Request certificate via ACM (us-east-1 region required)
- Add CNAME records to DNS for validation
- Associate with CloudFront distribution

---

## Post-Deployment

### Security Verification

```bash
# 1. Verify port 22 is closed
nmap -p 22 YOUR_EC2_IP
# Should show: filtered or closed

# 2. Verify direct IP access is blocked
curl http://YOUR_EC2_IP
# Should return: 403 Forbidden

# 3. Verify CloudFront access works
curl https://your-cloudfront-domain.cloudfront.net
# Should return: 200 OK

# 4. Verify WAF is active
curl -H "X-WAF-Test: true" https://yourdomain.com
# Check CloudWatch for WAF metrics

# 5. Test rate limiting
for i in {1..2100}; do curl -s https://yourdomain.com > /dev/null; done
# Should get blocked after 2000 requests
```

### CloudWatch Dashboard

```bash
# Create monitoring dashboard
./scripts/cloudwatch-dashboard-setup.sh
```

Access: AWS Console → CloudWatch → Dashboards → app-item-listing-tool

**Metrics shown:**
- CloudFront requests/errors
- WAF allowed/blocked requests
- EC2 CPU/memory
- Application errors

### Configure Alarms

```bash
# Setup SNS notifications
./scripts/cloudwatch-alarms-setup.sh your-email@example.com
```

**Alarms created:**
- High error rate (>5%)
- High request rate (possible DDoS)
- EC2 CPU > 80%
- WAF blocking spike

### Backup Configuration

```bash
# Automatic S3 sync is configured via cron
# Verify it's running:
aws ssm start-session --target i-xxxxxxxxxxxxx

crontab -l
# Should show: */15 * * * * /path/to/backup-script.sh
```

---

## Troubleshooting

### CloudFront Shows "502 Bad Gateway"

**Cause:** Origin (EC2) is not responding

**Fix:**
```bash
# 1. Check EC2 instance status
aws ec2 describe-instance-status --instance-ids i-xxxxxxxxxxxxx

# 2. Check application service
aws ssm start-session --target i-xxxxxxxxxxxxx
sudo systemctl status app_item_listing_tool

# 3. Check nginx
sudo systemctl status nginx

# 4. Check logs
sudo tail -f /var/log/app_item_listing_tool/error.log
```

### WAF Blocking Legitimate Traffic

**Cause:** False positives in WAF rules

**Fix:**
```bash
# 1. Check WAF logs
aws wafv2 list-web-acls --scope CLOUDFRONT
# Note the Web ACL ID

# 2. Review blocked requests in CloudWatch Logs

# 3. Temporarily switch to count mode (monitoring only)
aws wafv2 update-web-acl --scope CLOUDFRONT \
  --id <web-acl-id> \
  --default-action Count={}

# 4. After identifying false positive, update rule
```

### Cannot Connect via SSM

**Cause:** SSM agent not running or IAM role missing

**Fix:**
```bash
# 1. Verify instance has IAM role
aws ec2 describe-instances --instance-ids i-xxxxxxxxxxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# 2. Check SSM agent status (use SSH as backup)
ssh -i ~/.ssh/app-item-listing-tool_ec2 ubuntu@IP
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent

# 3. Restart SSM agent
sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent
```

### Secrets Manager Access Denied

**Cause:** EC2 IAM role doesn't have Secrets Manager permissions

**Fix:**
```bash
# 1. Update IAM role policy
aws iam put-role-policy \
  --role-name app-item-listing-tool-ec2-role \
  --policy-name SecretsManagerAccess \
  --policy-document file://secrets-policy.json

# secrets-policy.json:
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ],
    "Resource": "arn:aws:secretsmanager:*:*:secret:<app_name>/*"
  }]
}

# 2. Restart application
aws ssm start-session --target i-xxxxxxxxxxxxx
sudo systemctl restart {{ service_name }}
```

### CloudFront Cache Issues

**Cause:** Old content cached at edge locations

**Fix:**
```bash
# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id E123456EXAMPLE \
  --paths "/*"

# Or specific paths
aws cloudfront create-invalidation \
  --distribution-id E123456EXAMPLE \
  --paths "/static/*" "/images/*"
```

---

## Architecture

### Complete System Architecture (February 2026)

```
┌───────────────────────────────────────────────────────────────────────────┐
│                          Users (Multi-User Support)                        │
│                     Each user has own data & credentials                   │
└────────────────────────────────┬──────────────────────────────────────────┘
                                 ↓
┌───────────────────────────────────────────────────────────────────────────┐
│                         CloudFront CDN                                     │
│  • Global Edge Locations (150+ worldwide)                                 │
│  • DDoS Protection (AWS Shield Standard - Free)                          │
│  • SSL/TLS Termination                                                    │
│  • Response Caching (reduces origin load 60-80%)                         │
│  • Custom Header Validation (X-Custom-Header)                            │
└────────────────────────────────┬──────────────────────────────────────────┘
                                 ↓
┌───────────────────────────────────────────────────────────────────────────┐
│                            AWS WAF                                         │
│  • Rate Limiting (2000 req/5min per IP)                                  │
│  • SQL Injection Protection (AWS Managed Rules)                           │
│  • XSS Protection (AWS Managed Rules)                                     │
│  • Bot Detection & Mitigation                                             │
│  • Geographic Blocking (optional)                                         │
│  • IP Reputation Lists                                                    │
└────────────────────────────────┬──────────────────────────────────────────┘
                                 ↓
┌───────────────────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                                    │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  Security Group (CloudFront IPs only)                           │     │
│  │  • Port 80  (HTTP - redirects to HTTPS)                        │     │
│  │  • Port 443 (HTTPS - from CloudFront only)                     │     │
│  │  • Port 22  CLOSED (SSH disabled, use SSM instead)             │     │
│  └──────────────────────────┬──────────────────────────────────────┘     │
│                             ↓                                             │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │  EC2 Instance (t3.nano/micro, Ubuntu 22.04 LTS)                │     │
│  │  ┌───────────────────────────────────────────────────────────┐  │     │
│  │  │  Nginx (Reverse Proxy & Static File Server)              │  │     │
│  │  │  • Validates CloudFront header                           │  │     │
│  │  │  • Blocks direct IP access                               │  │     │
│  │  │  • Serves /static/ files directly                        │  │     │
│  │  │  • Gzip compression                                       │  │     │
│  │  └──────────────────┬────────────────────────────────────────┘  │     │
│  │                     ↓                                            │     │
│  │  ┌───────────────────────────────────────────────────────────┐  │     │
│  │  │  Gunicorn (WSGI Server)                                   │  │     │
│  │  │  • Workers: 2 (reduces duplicate logs)                    │  │     │
│  │  │  • Threads per worker: 4                                  │  │     │
│  │  │  • Timeout: 120 seconds                                   │  │     │
│  │  │  • Graceful restarts                                      │  │     │
│  │  └──────────────────┬────────────────────────────────────────┘  │     │
│  │                     ↓                                            │     │
│  │  ┌───────────────────────────────────────────────────────────┐  │     │
│  │  │  Flask Application                                        │  │     │
│  │  │                                                           │  │     │
│  │  │  Features:                                                │  │     │
│  │  │  • Multi-User Support (complete data isolation)          │  │     │
│  │  │  • User authentication & session management              │  │     │
│  │  │  • Per-user CSV files & SKU counters                     │  │     │
│  │  │  • Per-user eBay credentials                             │  │     │
│  │  │  • CloudWatch custom metrics                             │  │     │
│  │  │  • SNS alert integration                                 │  │     │
│  │  │  • S3 versioning & lifecycle management                  │  │     │
│  │  │  • Application-level security (IP blocking, rate limit)  │  │     │
│  │  │                                                           │  │     │
│  │  │  Services:                                                │  │     │
│  │  │  • ComicService, CSVService, S3Service                   │  │     │
│  │  │  • EbayService (per-user credential caching)             │  │     │
│  │  │  • UserSecretsService (manage user credentials)          │  │     │
│  │  │  • CloudWatchService (send metrics)                      │  │     │
│  │  │  • SNSService (send alerts)                              │  │     │
│  │  │  • HealthCheckService, TrashService, SnapshotService     │  │     │
│  │  │                                                           │  │     │
│  │  │  Security:                                                │  │     │
│  │  │  • NO credentials on disk (all from Secrets Manager)     │  │     │
│  │  │  • IAM role for all AWS access                           │  │     │
│  │  │  • Session-based authentication                          │  │     │
│  │  │  • CSRF protection                                        │  │     │
│  │  └──────────────────┬────────────────────────────────────────┘  │     │
│  └────────────────────┼────────────────────────────────────────────┘     │
└───────────────────────┼──────────────────────────────────────────────────┘
                        │
                        │ (IAM Role - No credentials needed!)
                        │
        ┌───────────────┼───────────────┬──────────────┬──────────────┐
        ↓               ↓               ↓              ↓              ↓
┌─────────────┐  ┌────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│  S3 Bucket  │  │  Secrets   │  │CloudWatch│  │   SNS    │  │   SSM    │
│             │  │  Manager   │  │          │  │          │  │          │
│ Features:   │  │            │  │ Metrics: │  │ Topics:  │  │ Session  │
│ • Versioning│  │ App-Level: │  │ • API    │  │ {app}-   │  │ Manager  │
│   Enabled   │  │   {app}/   │  │   Request│  │  alerts  │  │          │
│ • 30 day    │  │   prod     │  │   Count  │  │          │  │ • No SSH │
│   retention │  │            │  │ • Response│ │ Alerts:  │  │   keys   │
│ • ALWAYS    │  │ Per-User:  │  │   Time   │  │ • Email  │  │   needed │
│   ONLINE    │  │   {user}/  │  │ • Error  │  │ • SMS    │  │ • Audit  │
│   (No       │  │   prod     │  │   Count  │  │   (opt)  │  │   trail  │
│   Glacier!) │  │   (eBay)   │  │ • User   │  │          │  │          │
│             │  │            │  │   Actions│  │          │  │          │
│ Structure:  │  │ Dynamic:   │  │          │  │          │  │          │
│ users/      │  │ • {user}/  │  │ Alarms:  │  │          │  │          │
│  {user}/    │  │   prod     │  │ • HighCPU│  │          │  │          │
│   images/   │  │   created  │  │ • LowDisk│  │          │  │          │
│   backups/  │  │   on       │  │ • Errors │  │          │  │          │
│   exports/  │  │   demand   │  │ • Slow   │  │          │  │          │
│   snapshots/│  │            │  │   Resp   │  │          │  │          │
│   trash/    │  │ Tags:      │  │          │  │          │  │          │
│             │  │ • APP_NAME │  │ Custom   │  │          │  │          │
│ Lifecycle:  │  │ • Username │  │ Namespace│  │          │  │          │
│ • Delete old│  │ • Type     │  │          │  │          │  │          │
│   versions  │  │            │  │          │  │          │  │          │
│   after 30d │  │            │  │          │  │          │  │          │
│ • Delete    │  │            │  │          │  │          │  │          │
│   trash     │  │            │  │          │  │          │  │          │
│   after 30d │  │            │  │          │  │          │  │          │
└─────────────┘  └────────────┘  └──────────┘  └──────────┘  └──────────┘
```

### Data Flow Examples

**User Login & Access:**
```
User → CloudFront → WAF → Nginx → Gunicorn → Flask
                                              ↓
                                    Check Secrets Manager
                                    {username}/production
                                              ↓
                                    Load user's CSV:
                                    instance/data/{username}-items.csv
                                              ↓
                                    Return user's data only
```

**Image Upload:**
```
User uploads image → Flask validates → S3Service
                                       ↓
                                    S3: users/{username}/images/{filename}
                                       ↓
                                    CloudWatch: log metric
                                    (ImageUpload, username={user})
```

**eBay API Call:**
```
User action → EbayService
              ↓
              Check credential cache for {username}
              ↓
              If not cached, fetch from Secrets Manager:
              {username}/production
              ↓
              Cache credentials (per-user)
              ↓
              Make eBay API call with user's credentials
              ↓
              CloudWatch: log metric
              (EbayAPICall, username={user}, endpoint=search)
```

**Alert Triggered:**
```
CloudWatch detects alarm condition
(e.g., High CPU > 80%)
              ↓
SNS publishes to {app}-alerts topic
              ↓
Email sent to subscribed address
Subject: [WARNING] High CPU Usage
Body: CPU at 85%, investigate immediately
```

### Security Layers

**Layer 1: CloudFront**
- DDoS protection (AWS Shield)
- TLS 1.2+ only
- Geographic restrictions (optional)

**Layer 2: WAF**
- Rate limiting
- SQL injection prevention
- XSS prevention
- Bot detection

**Layer 3: Network (VPC + Security Group)**
- CloudFront IPs only
- No public SSH (port 22 closed)

**Layer 4: Application (Nginx)**
- Validates CloudFront headers
- Blocks direct IP access

**Layer 5: Credentials**
- No secrets on disk
- IAM roles for AWS services
- Secrets Manager for sensitive data

**Layer 6: System (EC2)**
- UFW firewall
- Fail2ban
- Automatic security updates
- SSM only access

---

## Next Steps

### After Successful Deployment

1. **Test Application**
   - Create test comic listing
   - Upload images
   - Test eBay listing creation

2. **Monitor for 24-48 Hours**
   - Check CloudWatch dashboard
   - Review WAF logs
   - Verify no legitimate traffic blocked

3. **Optimize CloudFront Caching**
   - Adjust TTLs based on usage
   - Configure cache behaviors for static content

4. **Setup Backup Verification**
   - Test S3 backup restore
   - Verify database exports

5. **Document Custom Changes**
   - Keep notes on any configuration tweaks
   - Update DNS records list

### Maintenance Tasks

**Weekly:**
- Review CloudWatch metrics
- Check WAF blocked requests logs

**Monthly:**
- Review AWS costs
- Update application dependencies
- Test disaster recovery

**Quarterly:**
- Rotate Secrets Manager secrets
- Review and update WAF rules
- Test failover procedures

---

**Version:** 5.0  
**Last Updated:** February 8, 2026  
**Next Review:** May 2026

