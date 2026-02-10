# Deployment Documentation

**Production Infrastructure:** AWS EC2 + CloudFront + WAF + Secrets Manager  
**Version:** 5.0  
**Last Updated:** February 8, 2026

---

## ⚡ Quick Start

### 1. Configure Your App (Optional)

Want to rename the app? Edit this file first:

**File:** `deployment/group_vars/all.yml`

```yaml
app_name: app_item_listing_tool              # Change to: katlo, listkit, etc.
app_display_name: "App Item Listing Tool"    # Display name
app_url: "https://github.com/yourusername/app_item_listing_tool"
```

One change renames everything! See [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md#application-configuration) for details.

### 2. Deploy Everything

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

That's it! Creates entire infrastructure + deploys app.

---

## 📖 Quick Navigation

### 🚀 Getting Started

- **New Deployment** → [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md) then [DEPLOYMENT_COMPLETE_GUIDE.md](DEPLOYMENT_COMPLETE_GUIDE.md)
- **Daily Operations** → [OPERATIONS.md](OPERATIONS.md)
- **Secret Management** → [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)
- **Troubleshooting** → [DEPLOYMENT_COMPLETE_GUIDE.md#troubleshooting](DEPLOYMENT_COMPLETE_GUIDE.md#troubleshooting)

### 📚 Documentation Files (Essential 6)

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[README.md](README.md)** | Overview, quick start, architecture | Start here |
| **[DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md)** | Prerequisites, checklist, credentials, IAM roles | Before deploying |
| **[DEPLOYMENT_COMPLETE_GUIDE.md](DEPLOYMENT_COMPLETE_GUIDE.md)** | Complete deployment & troubleshooting | During deployment |
| **[OPERATIONS.md](OPERATIONS.md)** | Daily ops, maintenance, security operations | Daily/weekly tasks |
| **[SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)** | Secret rotation, vault management | Managing secrets |
| **[MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)** | Multi-user setup, user management, eBay credentials | Adding users |
| **[PRODUCTION_NOTES.md](PRODUCTION_NOTES.md)** | Environment reference, quick commands | Production ops |
| **[DEVELOPMENT_NOTES.md](DEVELOPMENT_NOTES.md)** | Implementation notes, recent changes, troubleshooting | Development reference |

**8 files total** - Each serves a unique purpose, zero duplication!

**Additional References:**
- **Security technical details:** `/app/SECURITY.md` (technical details about `app/security.py`)
- **Scripts documentation:** `scripts/README.md` (script reference)
- **Instance structure:** `/instance/README.md` (directory explanation)
- **Analysis & reviews:** `/docs/analysis/` (Multi-user implementation review, February 2026)

---

## 🏗️ Architecture Overview

```
User Traffic
    ↓
CloudFront CDN (DDoS Protection + Caching)
    ↓
AWS WAF (Rate Limiting + Security Rules)
    ↓
EC2 Instance (Ubuntu 22.04, t3.nano/micro)
    ├→ Nginx (HTTP server + static files)
    ├→ Gunicorn (WSGI server, 2 workers)
    └→ Flask (your application)
         ↓
    IAM Role (no AWS credentials needed!)
         ↓
    ┌────┴────┐
    ↓         ↓
S3 Bucket   AWS Secrets Manager
(images)    (all credentials)
```

### Stack Layers (No Redundancy!)

Each layer serves a unique purpose:

1. **CloudFront** - Global CDN, DDoS protection (AWS Shield), edge caching
2. **AWS WAF** - Rate limiting (2000 req/5min), SQL/XSS protection, managed rules
3. **Nginx** - HTTP server, static file serving, reverse proxy (industry standard)
4. **Gunicorn** - WSGI server for Flask (required for production)
5. **Flask** - Your application framework

**Why all layers?** Each is necessary - removing any would break functionality or violate production best practices.

### Key Features

**Security & Infrastructure:**
- ✅ **CloudFront CDN** - Global edge caching, DDoS protection (AWS Shield)
- ✅ **AWS WAF** - Rate limiting (2000 req/5min), SQL injection/XSS protection
- ✅ **Application Security** - IP blocking, attack detection (30+ patterns), rate limiting (100 req/min)
- ✅ **Zero Secrets on Disk** - AWS Secrets Manager + IAM roles
- ✅ **Encrypted Vault** - Ansible Vault in git (safe to commit!)
- ✅ **SSM Access** - No SSH keys needed

**Multi-User Support (NEW):**
- ✅ **Complete Data Isolation** - Per-user CSV files, images, backups, exports
- ✅ **User-Specific eBay Credentials** - Each user manages own API keys
- ✅ **Per-User S3 Prefixes** - `/users/{username}/` for all data

**Monitoring & Alerting (NEW):**
- ✅ **CloudWatch Metrics** - Custom app metrics (requests, response time, errors)
- ✅ **Pre-Configured Alarms** - High CPU, low disk, errors, slow responses
- ✅ **SNS Email Alerts** - Instant notifications for critical events

**Storage & Data Protection (NEW):**
- ✅ **S3 Versioning** - Recover deleted files (configurable retention)
- ✅ **Always Online** - Files never move to Glacier (instant access 24/7)
- ✅ **Configurable App Name** - Single variable controls all AWS resource names

**Cost:** ~$30/month (t3.nano + monitoring)

---

## 🚀 Quick Start

### New Deployment (15-20 minutes)

```bash
# 1. Install prerequisites
pip install awscli boto3 ansible
brew install jq  # macOS, or: sudo apt-get install jq

# 2. Create secrets vault
cd deployment
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
# Use template from DEPLOYMENT_PREP.md

# 3. Run complete automated setup
./scripts/infra-complete-setup.sh

# 4. Update DNS to CloudFront domain (shown in output)

# Done! Application is live.
```

### Update Existing Application

```bash
# After code changes
git add . && git commit -m "Your changes" && git push

# Deploy
cd deployment
./scripts/app-deploy.sh update
```

---

## 📋 Common Operations

### Deploy Code Updates

```bash
cd deployment
./scripts/app-deploy.sh update
```

### View Application Logs

```bash
./scripts/app-deploy.sh logs

# Or live logs via SSM
aws ssm start-session --target i-xxxxxxxxxxxxx
sudo tail -f /var/log/app_item_listing_tool/error.log
```

### Check Application Status

```bash
./scripts/app-deploy.sh status
```

### Restart Application

```bash
./scripts/app-deploy.sh restart
```

### Access Server

```bash
# Method 1: SSM (no SSH key needed)
aws ssm start-session --target i-xxxxxxxxxxxxx

# Method 2: SSH (if key exists)
ssh -i ~/.ssh/app-item-listing-tool_ec2 ubuntu@YOUR_IP
```

### Rotate Secrets (Zero Downtime)

```bash
# 1. Edit vault, add _new secret
ansible-vault edit group_vars/production/vault.yml --vault-password-file ~/.vault_pass

# 2. Create pending version
./scripts/secret-rotate.sh ebay_production_token

# 3. Test, then promote
./scripts/secret-promote.sh
```

**Full procedures:** [OPERATIONS.md](OPERATIONS.md)

### Invalidate CloudFront Cache

```bash
aws cloudfront create-invalidation \
  --distribution-id E123456EXAMPLE \
  --paths "/*"
```

---

## 🔒 Security

### Multiple Protection Layers

1. **CloudFront** - DDoS protection, TLS 1.2+
2. **WAF** - Rate limiting, SQL injection/XSS prevention
3. **Network** - CloudFront IPs only, no direct EC2 access
4. **Application** - Origin header validation
5. **Secrets** - AWS Secrets Manager, no disk storage
6. **System** - UFW firewall, Fail2ban, auto-updates

### Secret Management

- **Source of Truth:** Ansible Vault (encrypted, in git)
- **Runtime:** AWS Secrets Manager (IAM role access)
- **Server:** No .env file, no secrets on disk
- **Rotation:** Zero-downtime with AWSPENDING/AWSCURRENT

**Details:** [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)

---

## 📊 Monitoring

### CloudWatch Dashboard

AWS Console → CloudWatch → Dashboards → app-item-listing-tool

**Metrics:**
- CloudFront requests/errors
- WAF allowed/blocked requests  
- EC2 CPU/memory/disk
- Application custom metrics

### Alarms Setup

```bash
./scripts/cloudwatch-alarms-setup.sh your-email@example.com
```

**Alerts for:**
- High error rate
- High request rate
- WAF blocking spike
- EC2 resource usage
- Disk space

### Logs

**CloudWatch:** `/aws/cloudfront/...`, `/aws/waf/...`  
**Server:** `/var/log/app_item_listing_tool/*.log`

---

## 🆘 Quick Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| CloudFront 502 | Check EC2 status, restart app |
| Secrets not loading | Verify IAM role, check Secrets Manager |
| WAF blocking traffic | Review WAF logs, adjust rules |
| Cannot connect SSM | Restart SSM agent, check IAM role |
| High costs | Review CloudWatch costs, optimize cache |

**Full guide:** [DEPLOYMENT_COMPLETE_GUIDE.md#troubleshooting](DEPLOYMENT_COMPLETE_GUIDE.md#troubleshooting)

---

## 📅 Maintenance Schedule

**Daily:** Monitor dashboard, check logs  
**Weekly:** Review WAF blocks, verify backups  
**Monthly:** Update dependencies, review costs  
**Quarterly:** Rotate secrets, test DR

**Detailed schedule:** [OPERATIONS.md#maintenance-schedule](OPERATIONS.md#maintenance-schedule)

---

## 🔧 Key Scripts Reference

```bash
# Infrastructure
./scripts/infra-complete-setup.sh       # Complete setup (one command)

# Deployment
./scripts/app-deploy.sh setup      # Initial deployment
./scripts/app-deploy.sh update     # Update application
./scripts/app-deploy.sh restart    # Restart app
./scripts/app-deploy.sh logs       # View logs
./scripts/app-deploy.sh status     # Check status

# Secrets
./scripts/secret-sync-vault.sh    # Sync vault to AWS
./scripts/secret-rotate.sh <key>      # Rotate secret
./scripts/secret-promote.sh           # Promote rotation
./scripts/migrate-to-vault.sh         # Convert secrets.env

# Monitoring
./scripts/cloudwatch-alarms-setup.sh  # Setup alerts
```

---

## 💰 Cost Estimate

```
EC2 t3.nano (reserved):  $1.90/month
S3 Storage:              $1-2/month
CloudFront:              $5-10/month
AWS WAF:                 $8-12/month
Secrets Manager:         $4/month
CloudWatch:              $1-2/month
──────────────────────────────────
Total:                   $21-31/month
```

**Optimization:** Use t3.nano reserved instance (1yr) for lowest cost

---

## ✅ Deployment Checklist

See [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md) for complete prerequisites checklist.

### Quick Checklist

**Before Deploying:**
- [ ] AWS CLI configured
- [ ] Ansible installed
- [ ] Vault password file created
- [ ] All secrets in vault.yml

**After Deploying:**
- [ ] Application accessible via CloudFront
- [ ] Direct IP blocked (403)
- [ ] Secrets in AWS Secrets Manager
- [ ] Monitoring active


---

## 📞 Getting Help

### Documentation

1. **Prerequisites** → [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md)
2. **Deployment** → [DEPLOYMENT_COMPLETE_GUIDE.md](DEPLOYMENT_COMPLETE_GUIDE.md)
3. **Daily Ops** → [OPERATIONS.md](OPERATIONS.md)
4. **Secrets** → [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)

### External Resources

- [AWS CloudFront Docs](https://docs.aws.amazon.com/cloudfront/)
- [AWS WAF Docs](https://docs.aws.amazon.com/waf/)
- [AWS Secrets Manager Docs](https://docs.aws.amazon.com/secretsmanager/)
- [AWS SSM Docs](https://docs.aws.amazon.com/systems-manager/)

### Tools

- [AWS Pricing Calculator](https://calculator.aws/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)
- [Security Headers](https://securityheaders.com/)

---

## 🎯 Next Steps

### For New Deployments

1. Read [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md)
2. Gather all prerequisites
3. Follow [DEPLOYMENT_COMPLETE_GUIDE.md](DEPLOYMENT_COMPLETE_GUIDE.md)
4. Learn [OPERATIONS.md](OPERATIONS.md) for daily tasks

### For Existing Deployments

1. Review [OPERATIONS.md](OPERATIONS.md) for daily procedures
2. Set up monitoring and alerts
3. Test secret rotation process
4. Document any custom configurations

---

**Ready to deploy?** → [DEPLOYMENT_PREP.md](DEPLOYMENT_PREP.md)  
**Need to operate?** → [OPERATIONS.md](OPERATIONS.md)  
**Managing secrets?** → [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)

---

**Version:** 6.0  
**Last Updated:** February 9, 2026

