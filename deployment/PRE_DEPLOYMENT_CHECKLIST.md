# Pre-Deployment Checklist - Start Fresh

**Date:** February 14, 2026  
**Purpose:** Ensure everything is configured correctly before manual deployment

---

## ✅ Configuration Items to Update

### 1. Application Identity

**File:** `deployment/group_vars/all.yml`

```yaml
# UPDATE THESE:
app_name: rampe                                        # ✅ Set to your app name
app_display_name: "Rampe"                              # ✅ Set to display name
app_url: "https://github.com/YOUR_USERNAME/rampe"      # ⚠️ CHANGE YOUR_USERNAME
```

**Action Required:**
- [ ] Change `app_url` from `yourusername` to your actual GitHub username

---

### 2. AWS Configuration

**File:** `deployment/group_vars/production/vault.yml` (encrypted)

You'll need to create/edit this vault file with:

```bash
# Decrypt vault (or create new)
ansible-vault edit deployment/group_vars/production/vault.yml
```

**Required variables:**
```yaml
vault_git_repo: "https://github.com/YOUR_USERNAME/rampe.git"
vault_aws_region: "us-east-1"
vault_s3_bucket_name: "your-unique-bucket-name"
vault_s3_folder: "production"
vault_app_username: "admin"
vault_app_password: "your_secure_password"
vault_sns_topic_arn: ""  # Optional
```

**Action Required:**
- [ ] Set your actual GitHub repository URL
- [ ] Choose a unique S3 bucket name
- [ ] Set a secure admin password

---

### 3. Local Environment File (Development Only)

**File:** `.env.example` → Copy to `.env` for local development

```bash
cp .env.example .env
```

Then edit `.env`:

```dotenv
# UPDATE THESE:
SECRET_KEY=change-this-to-a-random-secret-key         # ⚠️ GENERATE RANDOM
USERS=admin:your_secure_password                      # ⚠️ CHANGE PASSWORD
AWS_REGION=us-east-1                                  # ✅ Already updated
S3_BUCKET=your-s3-bucket-name                         # ⚠️ CHANGE THIS
```

**Action Required:**
- [ ] Generate random SECRET_KEY
- [ ] Set secure password
- [ ] Update S3 bucket name

---

### 4. SSL/Domain Configuration (If Using Custom Domain)

**File:** `deployment/scripts/ssl-add-config.sh`

```bash
# Line 8 - UPDATE THIS:
DOMAIN="your-domain.com"  # ⚠️ CHANGE to your actual domain
```

**Action Required:**
- [ ] Update DOMAIN variable to your actual domain (or leave as placeholder if using IP only)

---

### 5. eBay Token Generator (If Using eBay Integration)

**File:** `deployment/scripts/util-generate-ebay-token.sh`

The script now uses generic placeholders. You'll need to:

**Action Required:**
- [ ] Update domain references when you generate eBay tokens
- [ ] Set eBay redirect URI in eBay developer portal to your actual domain

---

## ✅ Files Already Cleaned Up

### ✅ No Hardcoded Values Found In:

- [ ] ✅ Python application code (`app/**/*.py`) - Clean!
- [ ] ✅ Ansible playbooks (`deployment/playbooks/*.yml`) - Uses variables!
- [ ] ✅ Systemd templates (`deployment/files/*.j2`) - Uses variables!
- [ ] ✅ Most shell scripts - Uses `APP_NAME` variable!

### ✅ Generic Placeholders Set:

- [ ] ✅ `.env.example` - Uses generic placeholders
- [ ] ✅ `ssl-add-config.sh` - Uses `DOMAIN` variable
- [ ] ✅ `util-generate-ebay-token.sh` - Generic domain placeholder

---

## 📋 Pre-Deployment Verification

### Configuration Check

```bash
# 1. Check app_name is set
grep "^app_name:" deployment/group_vars/all.yml
# Should show: app_name: rampe (or your custom name)

# 2. Check for any remaining hardcoded domains
grep -r "badartink" deployment/ --exclude-dir=.git
# Should return: (empty)

# 3. Check for any remaining hardcoded buckets
grep -r "badart-listing-tool" . --exclude-dir=.git --exclude-dir=.venv
# Should return: (empty)

# 4. Verify vault file exists
ls -la deployment/group_vars/production/vault.yml
# Should exist (encrypted)
```

---

## 🚀 Ready to Deploy Checklist

### Before You Start:

- [ ] **AWS Account Setup**
  - [ ] AWS account created
  - [ ] IAM user with admin access
  - [ ] AWS CLI configured (`aws configure`)
  
- [ ] **GitHub Repository**
  - [ ] Repository created
  - [ ] Code pushed to GitHub
  - [ ] Repository is private/public as intended
  
- [ ] **Configuration Files**
  - [ ] `app_url` updated with your GitHub username
  - [ ] Vault file created/updated with your values
  - [ ] `.env` created for local development
  - [ ] S3 bucket name chosen (must be globally unique)
  
- [ ] **Domain/SSL (Optional)**
  - [ ] Domain purchased and DNS configured
  - [ ] DOMAIN variable updated in `ssl-add-config.sh`
  
- [ ] **eBay Integration (Optional)**
  - [ ] eBay developer account created
  - [ ] eBay app registered
  - [ ] Redirect URIs configured

---

## 🛠️ Quick Fixes Applied

### What Was Updated:

1. **`.env.example`**
   - ✅ Removed hardcoded bucket name `badart-listing-tool`
   - ✅ Changed region from `us-east-2` to `us-east-1`
   - ✅ Added generic placeholder `your-s3-bucket-name`

2. **`deployment/scripts/ssl-add-config.sh`**
   - ✅ Removed hardcoded domain `app.badartink.com`
   - ✅ Added `DOMAIN` variable with placeholder `your-domain.com`
   - ✅ Updated all SSL certificate paths to use `${DOMAIN}`
   - ✅ Updated curl test to use `${DOMAIN}`

3. **`deployment/scripts/util-generate-ebay-token.sh`**
   - ✅ Removed hardcoded domain `app.badartink.com`
   - ✅ Added generic placeholder `your-domain.com`

4. **All Other Files**
   - ✅ Already using variables (app_name, app_user, etc.)
   - ✅ No hardcoded application names found
   - ✅ Deployment playbooks use proper variable substitution

---

## 📝 Configuration Summary

### What's Configurable:

| Variable | Location | Default | Action |
|----------|----------|---------|--------|
| `app_name` | `group_vars/all.yml` | `rampe` | ✅ OK or customize |
| `app_url` | `group_vars/all.yml` | Has placeholder | ⚠️ UPDATE |
| `vault_git_repo` | `vault.yml` | Encrypted | ⚠️ UPDATE |
| `vault_s3_bucket_name` | `vault.yml` | Encrypted | ⚠️ UPDATE |
| `vault_app_password` | `vault.yml` | Encrypted | ⚠️ UPDATE |
| `DOMAIN` | `ssl-add-config.sh` | `your-domain.com` | ⚠️ UPDATE if using SSL |
| `S3_BUCKET` | `.env.example` | Placeholder | ⚠️ UPDATE for dev |

### What's Already Good:

| Item | Status |
|------|--------|
| App user security | ✅ Configured |
| Variable usage | ✅ All using variables |
| CSV storage | ✅ No database needed |
| AWS IAM roles | ✅ Configured for EC2 |
| Systemd hardening | ✅ 20+ security features |
| Documentation | ✅ Organized |

---

## 🎯 Next Steps

### 1. Update Required Values

```bash
# 1. Update app_url in group_vars/all.yml
vim deployment/group_vars/all.yml
# Change: yourusername → your_actual_username

# 2. Create/edit vault file
ansible-vault edit deployment/group_vars/production/vault.yml
# Set: vault_git_repo, vault_s3_bucket_name, vault_app_password

# 3. Update domain (if using SSL)
vim deployment/scripts/ssl-add-config.sh
# Change: your-domain.com → your.actual-domain.com
```

### 2. Verify Configuration

```bash
# Run verification checks
grep "yourusername" deployment/group_vars/all.yml
# Should return: (empty after you update it)

grep "your-domain.com" deployment/scripts/ssl-add-config.sh
# Should return: your actual domain after update

# Check vault is configured
ansible-vault view deployment/group_vars/production/vault.yml
# Should show your actual values
```

### 3. Deploy!

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

---

## 📞 Support

If you encounter issues:

1. **Configuration:** See `deployment/DEPLOYMENT_PREP.md`
2. **Deployment:** See `deployment/DEPLOYMENT_COMPLETE_GUIDE.md`
3. **Operations:** See `deployment/OPERATIONS.md`
4. **Security:** See `deployment/SECURITY_HARDENING.md`

---

## Summary

✅ **Cleaned up all hardcoded values**  
✅ **Everything uses variables**  
⚠️ **Need to update 3-4 configuration values**  
⚠️ **Then ready to deploy!**

**The app is 95% ready - just need your specific values (GitHub username, S3 bucket name, passwords).**

