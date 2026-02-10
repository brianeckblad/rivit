# Development & Implementation Notes

**Last Updated:** February 9, 2026  
**Purpose:** Technical notes from multi-user implementation and AWS improvements

---

## 📋 Recent Changes (February 2026)

### ✅ Multi-User Support Implemented
- Per-user CSV files and data isolation
- Per-user eBay credentials via AWS Secrets Manager
- Account page for users to manage their own credentials
- Complete data separation (S3, backups, snapshots, trash)

### ✅ AWS Monitoring Implemented
- CloudWatch metrics and custom alarms
- SNS email notifications
- S3 versioning with configurable retention
- S3 lifecycle (files stay online, no Glacier)

### ✅ App Name Variable
- Configurable `app_name` in `deployment/group_vars/all.yml`
- No hardcoded app names in code or scripts
- Easy to rename application

---

## 🔐 Security Improvements

### eBay Credentials Isolation (CRITICAL FIX)
**Issue:** User A's eBay credentials could be used by User B due to shared caching.

**Fix Implemented:**
- Per-user credential caching in `EbayService`
- Per-user OAuth token caching
- Username added to search cache keys
- User-specific secrets in AWS Secrets Manager (`{username}/production`)

**Files Modified:**
- `app/services/ebay_service.py` - Per-user credential caching
- `app/services/user_secrets_service.py` - NEW service for managing user secrets
- `app/routes/api/account.py` - API endpoints for credential management
- `app/templates/account.html` - UI for users to manage credentials
- `app/utils/user_context.py` - Updated to use new secrets service

---

## 📊 S3 Configuration

### Always-Online Strategy
**Requirement:** Items must be accessible 24/7 with zero retrieval delays.

**Implementation:**
- Current files: ALWAYS in Standard storage
- Old versions: Kept online for X days (configurable)
- NO Glacier or Infrequent Access transitions
- Lifecycle only deletes old versions and trash

**Cost:** ~$10/month per 100GB (worth it for reliability)

**Configuration:**
```yaml
# deployment/group_vars/all.yml
s3_version_retention_days: 30  # Configurable: 7-90 days
```

---

## 🎯 CloudWatch Monitoring

### Metrics Tracked
- API request count (by endpoint, method, status)
- API response time
- User actions (login, upload, export)
- Error counts

### Alarms Configured
- High CPU (>80%)
- Low disk space (>85%)
- High error rate (>10 errors/5min)
- Slow responses (>2 seconds avg)

### Services Created
- `app/services/cloudwatch_service.py` - Send metrics to CloudWatch
- `app/services/sns_service.py` - Send email alerts
- `app/utils/monitoring.py` - Decorators for route monitoring

---

## 🔧 App Name Configuration

### How It Works
1. Set `app_name` in `deployment/group_vars/all.yml`
2. Deployment automatically uses it everywhere
3. AWS resources, server paths, services all use correct name

### What Gets Updated
- Secrets Manager: `{app_name}/production`
- SNS Topic: `{app_name}-alerts`
- CloudWatch Alarms: `{app_name}-*`
- EC2 Tags: `Name={app_name}`
- Server paths: `/home/ubuntu/{app_name}/`
- Service: `{app_name}.service`
- Logs: `/var/log/{app_name}/`

### Code Changes
- `app/config.py` - Reads `APP_NAME` environment variable
- `app/utils/user_context.py` - Uses `APP_NAME` for secret names
- `app/services/user_secrets_service.py` - Uses `APP_NAME` for tags
- `deployment/scripts/setup-monitoring.sh` - Reads `app_name` from `all.yml`

---

## 📁 File Organization

### Application Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      REQUEST FLOW (Multi-User)                       │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
                   ┌───────────────────────┐
                   │   User Authentication │
                   │  (session-based)      │
                   └──────────┬────────────┘
                              ↓
                   ┌───────────────────────┐
                   │ get_current_username()│
                   │  → Returns: "brian"   │
                   └──────────┬────────────┘
                              ↓
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ↓                                           ↓
┌──────────────────┐                      ┌──────────────────┐
│  Local Files     │                      │  S3 Storage      │
│                  │                      │                  │
│ instance/data/   │                      │ users/brian/     │
│   brian-items.csv│                      │   images/        │
│   brian-sku.txt  │                      │   backups/       │
│   brian/         │                      │   exports/       │
│     snapshots/   │                      │   snapshots/     │
│     trash/       │                      │   trash/         │
│     analytics/   │                      │                  │
│     exports/     │                      │ CloudWatch       │
│     uploads/     │                      │   Metrics        │
└──────────────────┘                      │                  │
                                          │ Secrets Manager  │
                                          │   brian/prod     │
                                          │   (eBay creds)   │
                                          └──────────────────┘
```

### Multi-User Data Isolation

```
User "brian" logs in:
    ↓
CSV File:      instance/data/brian-items.csv
SKU Counter:   instance/data/brian-sku.txt
S3 Prefix:     users/brian/
Secrets:       brian/production (if configured)
               OR {app_name}/production (fallback)

User "sarah" logs in:
    ↓
CSV File:      instance/data/sarah-items.csv
SKU Counter:   instance/data/sarah-sku.txt
S3 Prefix:     users/sarah/
Secrets:       sarah/production (if configured)
               OR {app_name}/production (fallback)

✅ Complete isolation - users cannot access each other's data
```

### CloudWatch & SNS Integration

```
Application Event:
    ↓
┌─────────────────────────────────┐
│  CloudWatchService              │
│  .log_metric()                  │
│    - metric_name                │
│    - value                      │
│    - dimensions (endpoint, user)│
└─────────────┬───────────────────┘
              ↓
         CloudWatch
              ↓
    Evaluates Alarms:
    • HighCPU > 80%
    • LowDisk > 85%
    • Errors > 10/5min
    • SlowResp > 2000ms
              ↓
         Alarm Triggered
              ↓
┌─────────────────────────────────┐
│  SNS Topic                      │
│  {app_name}-alerts              │
└─────────────┬───────────────────┘
              ↓
         Email Alert
    (subscribed addresses)
```

---

## 📁 File Organization

### User Data Structure
```
instance/data/
├── {username}-items.csv         # User's inventory
├── {username}-sku.txt           # User's SKU counter
└── {username}/
    ├── snapshots/               # User's backups
    ├── trash/                   # User's deleted items
    ├── analytics/               # User's analytics
    ├── exports/                 # User's exports
    └── uploads/                 # User's temp files
```

### S3 Structure
```
users/{username}/
├── images/                      # Per-user images
├── backups/                     # Per-user CSV backups
├── exports/                     # Per-user exports
├── snapshots/                   # Per-user snapshots
└── trash/                       # Per-user deleted items
```

---

## 🚀 Deployment Notes

### Initial Setup
```bash
cd deployment

# 1. Configure app identity
vim group_vars/all.yml
# Set: app_name, app_display_name, app_url

# 2. Setup monitoring
./scripts/setup-monitoring.sh

# 3. Deploy application
./scripts/app-deploy.sh update
```

### Adding Users
Admin creates users via web interface at `/account`:
1. Admin logs in
2. Goes to Account settings
3. Clicks "Add User"
4. Enters username and temporary password
5. System creates all directories and files
6. User logs in and changes password
7. User adds their own eBay credentials (optional)

### Cost Estimate
- EC2 t3.nano: $3.80/month
- S3 (Standard): $10/month (100GB)
- Secrets Manager: $6/month
- CloudFront: $5/month
- CloudWatch: $5/month
- SNS: $0.50/month
- **Total: ~$30.30/month**

---

## 🔍 Verification Commands

### Check App Name
```bash
# View configured name
grep "^app_name:" deployment/group_vars/all.yml

# Verify on server
ssh ubuntu@SERVER
echo $APP_NAME
```

### Check S3 Configuration
```bash
# Verify versioning enabled
aws s3api get-bucket-versioning --bucket YOUR_BUCKET

# Check lifecycle policy (should have 2 rules, no Glacier)
aws s3api get-bucket-lifecycle-configuration --bucket YOUR_BUCKET
```

### Check Monitoring
```bash
# List CloudWatch metrics
aws cloudwatch list-metrics --namespace AppItemListingTool

# View alarms
aws cloudwatch describe-alarms --alarm-name-prefix "YOUR_APP_NAME-"

# Check SNS subscriptions
aws sns list-subscriptions
```

---

## 📚 Essential Documentation

### Deployment Guides
- `deployment/README.md` - Overview and quick start
- `deployment/DEPLOYMENT_PREP.md` - Prerequisites and preparation
- `deployment/DEPLOYMENT_COMPLETE_GUIDE.md` - Complete deployment instructions
- `deployment/OPERATIONS.md` - Daily operations and maintenance
- `deployment/SECRET_MANAGEMENT.md` - Secret rotation and management
- `deployment/MULTI_USER_SUPPORT.md` - Multi-user setup and management
- `deployment/PRODUCTION_NOTES.md` - Quick reference commands

### Technical References
- `app/SECURITY.md` - Security implementation details
- `instance/README.md` - Instance directory structure
- `deployment/scripts/README.md` - Script documentation

---

## 🐛 Known Issues & Solutions

### Issue: User can't see their items
**Check:**
1. User is logged in correctly
2. CSV file exists: `instance/data/{username}-items.csv`
3. File permissions are correct

**Fix:**
```bash
cd /home/ubuntu/app_name/instance/data
touch {username}-items.csv
chown ubuntu:ubuntu {username}-items.csv
chmod 644 {username}-items.csv
```

### Issue: eBay API errors
**Check:**
1. User has credentials in Secrets Manager: `{username}/production`
2. OR app-level credentials exist: `{app_name}/production`
3. IAM role has Secrets Manager permissions

### Issue: CloudWatch metrics not appearing
**Check:**
1. IAM role has CloudWatch permissions
2. Application is sending metrics (check logs)
3. Wait 5 minutes for metrics to appear

---

## 🎓 Development Guidelines

### Adding New Features
1. Follow existing patterns in codebase
2. Use `user_context.py` functions for user-specific paths
3. Always check permissions before file operations
4. Log important actions with user context
5. Add monitoring where appropriate

### Testing Multi-User Features
1. Create test users
2. Test data isolation between users
3. Verify S3 prefix isolation
4. Check credential isolation
5. Test permission boundaries

### Code Quality
- Use type hints where possible
- Follow PEP 8 style guide
- Add docstrings to functions
- Handle exceptions gracefully
- Log errors with context

---

## 📞 Support & Troubleshooting

### Log Locations
```bash
# Application logs
/var/log/{app_name}/app.log
/var/log/{app_name}/error.log

# Service logs
journalctl -u {app_name}.service -f

# Nginx logs
/var/log/nginx/error.log
```

### Common Commands
```bash
# Restart application
sudo systemctl restart {app_name}

# View status
sudo systemctl status {app_name}

# Check configuration
cd /home/ubuntu/{app_name}
source .venv/bin/activate
python3 -c "from app import create_app; app = create_app('production'); print(app.config)"
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Set `app_name` in `group_vars/all.yml`
- [ ] Create encrypted vault with secrets
- [ ] Configure AWS credentials locally
- [ ] Review IAM permissions

### Deployment
- [ ] Run `setup-monitoring.sh`
- [ ] Subscribe to SNS email alerts
- [ ] Add SNS ARN to vault
- [ ] Run `app-deploy.sh update`

### Post-Deployment
- [ ] Verify application is running
- [ ] Check CloudWatch metrics appearing
- [ ] Test user login
- [ ] Verify S3 uploads working
- [ ] Test eBay integration

### User Setup
- [ ] Create admin user
- [ ] Test user creation
- [ ] Verify user data isolation
- [ ] Test eBay credential management
- [ ] Verify monitoring and alerts

---

**For detailed information, see the main deployment documentation in `/deployment/*.md`**


