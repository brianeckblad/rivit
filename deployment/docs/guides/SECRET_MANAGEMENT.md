# Secret Management Strategy

**Version:** 5.0  
**Date:** February 8, 2026

---

## Overview

This document describes the complete secret management workflow using:
- **Ansible Vault** - Encrypted secrets in git (safe to commit)
- **AWS Secrets Manager** - Runtime secrets (fetched by application)
- **Rotation Process** - Zero-downtime secret rotation

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Development Workflow                      │
└─────────────────────────────────────────────────────────────┘

Developer's Machine:
  ├── group_vars/vault.yml (Ansible Vault encrypted)
  ├── .vault_pass (never commit!)
  └── git commit (encrypted vault is safe)
       ↓
GitHub Repository:
  └── vault.yml (encrypted, safe in git)
       ↓
Deployment:
  ├── Ansible decrypts vault.yml
  ├── Uploads secrets to AWS Secrets Manager
  └── Application fetches from Secrets Manager
       ↓
Production:
  ├── No secrets on disk
  ├── Secrets Manager provides values
  └── IAM role authentication
```

---

## Secret Storage Locations

### 1. Ansible Vault (Source of Truth)

**File:** `deployment/group_vars/vault.yml`

**Contains:**
- All production secrets
- eBay API credentials
- Admin passwords
- GitHub tokens
- Secret keys

**Security:**
- ✅ Encrypted with AES256
- ✅ Safe to commit to git
- ✅ Requires password to decrypt
- ✅ Password stored locally only (`.vault_pass`)

### 2. AWS Secrets Manager (Runtime)

**Secret Name:** `app-item-listing-tool/production`

**Contains:**
- Same values as Ansible Vault
- Fetched by application at runtime
- Updated via deployment process

**Security:**
- ✅ No secrets on server disk
- ✅ IAM role authentication
- ✅ Automatic encryption at rest
- ✅ CloudTrail audit logs

---

## Workflow

### Sync Secrets to AWS Secrets Manager

The `setup-secrets-manager.yml` playbook automatically syncs secrets from Ansible Vault to AWS Secrets Manager:

```bash
cd deployment
source scripts/load-vars.sh
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass
```

**This playbook:**
1. ✅ Extracts vault variables from encrypted vault.yml
2. ✅ Creates AWS Secrets Manager secret via Ansible AWS module (not shell command)
3. ✅ Stores all secrets as JSON
4. ✅ Enables automatic 30-day rotation
5. ✅ Tags resources for tracking

**Technical Details:**
- Uses `query('varnames', '^vault_')` to safely extract vault variables (non-deprecated approach)
- Uses `amazon.aws.secretsmanager_secret` module for AWS operations (no shell commands, no sudo)
- No passwords needed on EC2 instance (IAM role handles authentication)

→ **Full Details:** [SECRETS_MANAGER_SETUP.md](SECRETS_MANAGER_SETUP.md)

---

### Initial Setup

```bash
# 1. Create vault password (OPTIONAL but RECOMMENDED)
#    Skip this if you prefer to enter password when prompted
echo "your-secure-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# 2. Create encrypted vault file
#    You'll be prompted for password if ~/.vault_pass doesn't exist
ansible-vault create deployment/group_vars/vault.yml \
  --vault-password-file ~/.vault_pass

# 3. Add secrets (see template below)

# 4. Commit to git (encrypted)
git add deployment/group_vars/vault.yml
git commit -m "Add encrypted secrets"
git push
```

### Editing Secrets

```bash
# Edit encrypted vault
ansible-vault edit deployment/group_vars/vault.yml \
  --vault-password-file ~/.vault_pass

# After saving, commit changes
git add deployment/group_vars/vault.yml
git commit -m "Update secrets"
git push
```

### Deployment Process

```bash
# Deploy with vault
cd deployment
./scripts/app-deploy.sh setup --vault-password-file ~/.vault_pass

# Or with password prompt
./scripts/app-deploy.sh setup --ask-vault-pass
```

**What happens:**
1. Ansible decrypts `vault.yml`
2. Secrets uploaded to AWS Secrets Manager
3. Application fetches from Secrets Manager
4. No secrets stored on server disk

---

## Secret Rotation Strategy

### Zero-Downtime Rotation Process

AWS Secrets Manager supports **versioning** with staging labels:

```
Secret Versions:
├── AWSCURRENT (active version)
└── AWSPENDING (new version being tested)
```

### Rotation Workflow

#### Option 1: Automatic Rotation (AWS Managed)

For compatible secrets (RDS, etc.), AWS can rotate automatically.

#### Option 2: Manual Rotation (Our Process)

For eBay tokens, API keys, etc.:

**Step 1: Add new secret to vault**
```yaml
# vault.yml
vault_ebay_production_token: v^1.1#i^1#...old-token...
vault_ebay_production_token_new: v^1.1#i^1#...new-token...  # ← Add this
```

**Step 2: Deploy with new secret**
```bash
# This creates AWSPENDING version
./scripts/rotate-secrets.sh ebay_production_token
```

**Step 3: Test with new secret**
```bash
# Application can test AWSPENDING version
# If successful, promote to AWSCURRENT
aws secretsmanager update-secret-version-stage \
  --secret-id <app_name>/production \
  --version-stage AWSCURRENT \
  --move-to-version-id <new-version-id>
```

**Step 4: Clean up old secret**
```yaml
# vault.yml (after successful rotation)
vault_ebay_production_token: v^1.1#i^1#...new-token...  # ← Now current
# Remove vault_ebay_production_token_new
```

### Rotation Script

**File:** `deployment/scripts/rotate-secrets.sh`

```bash
#!/bin/bash
# Rotate a secret from Ansible Vault to AWS Secrets Manager
# Usage: ./rotate-secrets.sh <secret-key>

SECRET_KEY="$1"
SECRET_NAME="app-item-listing-tool/production"

# 1. Get new value from vault
NEW_VALUE=$(ansible-vault view group_vars/vault.yml \
  --vault-password-file ~/.vault_pass | \
  grep "vault_${SECRET_KEY}_new:" | \
  cut -d: -f2- | tr -d ' ')

# 2. Get current secret JSON
CURRENT=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --query SecretString \
  --output text)

# 3. Update with new value (creates AWSPENDING)
UPDATED=$(echo "$CURRENT" | jq --arg key "$SECRET_KEY" --arg val "$NEW_VALUE" \
  '. + {($key): $val}')

aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME" \
  --secret-string "$UPDATED" \
  --version-stages AWSPENDING

echo "✓ New secret version created (AWSPENDING)"
echo "  Test your application with the new secret"
echo "  If successful, promote to AWSCURRENT:"
echo "  ansible-playbook playbooks/secret-promote.yml -e secret_key=YOUR_KEY"
```

---

## Vault File Template

**File:** `deployment/group_vars/vault.yml`

```yaml
---
# Production Secrets (Ansible Vault Encrypted)
# Edit with: ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass

# Application Secrets
vault_secret_key: "64-char-hex-string-here"
vault_app_secret_token: "32-char-hex-string-here"

# AWS Configuration
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "your-bucket-name"

# eBay Production Credentials
vault_ebay_production_app_id: "YourApp-YourApp-PRD-1234567890-a1b2c3d4"
vault_ebay_production_dev_id: "a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890"
vault_ebay_production_cert_id: "PRD-1234567890ab-cdef-1234-5678-90ab"
vault_ebay_production_token: "v^1.1#i^1#...long-token-here"

# eBay Sandbox Credentials (Optional)
vault_ebay_sandbox_app_id: "YourApp-YourApp-SBX-1234567890-a1b2c3d4"
vault_ebay_sandbox_dev_id: "a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890"
vault_ebay_sandbox_cert_id: "SBX-1234567890ab-cdef-1234-5678-90ab"
vault_ebay_sandbox_token: "v^1.1#i^1#...sandbox-token-here"

# Admin Credentials
vault_admin_username: "admin"
vault_admin_password: "secure-password-here"

# GitHub Deployment
vault_github_token: "ghp_your_personal_access_token_here"
vault_github_repo: "yourusername/your_app_name"
vault_github_branch: "main"

# CloudFront (Auto-populated during deployment)
vault_cloudfront_domain: ""
vault_cloudfront_distribution_id: ""

# Rotation Support (Add _new suffix for rotation)
# vault_ebay_production_token_new: "v^1.1#i^1#...new-token-during-rotation"
# vault_admin_password_new: "new-password-during-rotation"
```

---

## Deployment Integration

### Updated app-deploy.sh

The deployment script now:
1. Decrypts Ansible Vault
2. Extracts secrets
3. Uploads to AWS Secrets Manager
4. Application fetches from Secrets Manager

### Playbook Integration

**File:** `deployment/playbooks/deploy.yml`

```yaml
---
- name: Deploy Application
  hosts: production
  become: yes
  vars_files:
    - ../group_vars/vault.yml
  
  tasks:
    - name: Upload secrets to AWS Secrets Manager
      command: |
        aws secretsmanager put-secret-value \
          --secret-id <app_name>/production \
          --secret-string '{
            "SECRET_KEY": "{{ vault_secret_key }}",
            "EBAY_PRODUCTION_APP_ID": "{{ vault_ebay_production_app_id }}",
            "EBAY_PRODUCTION_TOKEN": "{{ vault_ebay_production_token }}",
            ...
          }'
      delegate_to: localhost
      run_once: true
```

---

## Security Best Practices

### Vault Password Management

**DO:**
- ✅ Store `.vault_pass` locally only
- ✅ Add to `.gitignore`
- ✅ Use strong, unique password
- ✅ Share via secure channel (1Password, etc.)
- ✅ Rotate vault password periodically

**DON'T:**
- ❌ Commit `.vault_pass` to git
- ❌ Share password via email/Slack
- ❌ Use same password as other systems
- ❌ Store in plaintext notes

### Secret Rotation Schedule

**Quarterly (Every 3 months):**
- eBay API tokens
- Admin passwords
- GitHub tokens
- Application secret keys

**Annually:**
- Vault encryption password
- AWS access keys
- SSL certificates

### Audit Trail

All secret access logged:
- **CloudTrail**: AWS Secrets Manager API calls
- **CloudWatch**: Application secret fetches
- **Ansible logs**: Deployment secret updates

View logs:
```bash
# CloudTrail - Secrets Manager access
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::SecretsManager::Secret

# CloudWatch - Application logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/app-item-listing-tool \
  --filter-pattern "Secret"
```

---

## Disaster Recovery

### Backup Secrets

```bash
# 1. Vault file is in git (encrypted)
git log deployment/group_vars/vault.yml

# 2. Export from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id app-item-listing-tool/production \
  --query SecretString \
  --output text > secrets-backup-$(date +%Y%m%d).json

# Encrypt backup
gpg --encrypt --recipient your@email.com secrets-backup-*.json
```

### Restore Secrets

```bash
# 1. From git (if vault file lost)
git checkout deployment/group_vars/vault.yml

# 2. From backup
aws secretsmanager put-secret-value \
  --secret-id <app_name>/production \
  --secret-string file://secrets-backup.json
```

---

## Common Workflows

### Add New Secret

```bash
# 1. Edit vault
ansible-vault edit deployment/group_vars/vault.yml \
  --vault-password-file ~/.vault_pass

# Add new secret:
# vault_new_api_key: "your-new-api-key"

# 2. Commit
git add deployment/group_vars/vault.yml
git commit -m "Add new API key"
git push

# 3. Deploy
cd deployment
./scripts/app-deploy.sh update --vault-password-file ~/.vault_pass
```

### Rotate eBay Token

```bash
cd deployment

# 1. Get new token from eBay
NEW_TOKEN="v^1.1#i^1#...new-token..."

# 2. Add to vault as _new
ansible-vault edit group_vars/vault.yml \
  --vault-password-file ~/.vault_pass
# Add: vault_ebay_production_token_new: "..."

# 3. Rotate secret
ansible-playbook playbooks/secret-rotate.yml \
  -e secret_key=ebay_production_token \
  --vault-password-file ~/.vault_pass

# 4. Test application
curl https://yourdomain.com/api/ebay/test

# 5. If successful, promote
ansible-playbook playbooks/secret-promote.yml \
  -e secret_key=ebay_production_token \
  --vault-password-file ~/.vault_pass

# 6. Clean up vault
ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass
# Move _new to main, remove _new suffix

# 7. Commit
git add deployment/group_vars/vault.yml
git commit -m "Rotate eBay production token"
git push
```

### Share Secrets with Team

```bash
# 1. Export vault password securely
echo "Vault password: $(cat ~/.vault_pass)"
# Share via 1Password, LastPass, etc.

# 2. New team member sets up
echo "received-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# 3. Test access
ansible-vault view deployment/group_vars/vault.yml \
  --vault-password-file ~/.vault_pass
```

---

## Troubleshooting

### "Decryption failed"

**Cause:** Wrong vault password

**Fix:**
```bash
# Verify password
cat ~/.vault_pass

# Try with prompt
ansible-vault view deployment/group_vars/vault.yml
```

### "Secret not found in Secrets Manager"

**Cause:** Secrets not uploaded during deployment

**Fix:**
```bash
# Manually upload
./scripts/secrets-manager-setup.sh deployment/group_vars/vault.yml
```

### "Application can't fetch secrets"

**Cause:** IAM role missing permissions

**Fix:**
```bash
# Add Secrets Manager permissions
aws iam put-role-policy \
  --role-name <app_name>-ec2-role \
  --policy-name SecretsManagerAccess \
  --policy-document file://secrets-policy.json
```

---

## Migration from secrets.env

If you currently use `secrets.env`:

```bash
# 1. Create vault from secrets.env
./scripts/migrate-to-vault.sh secrets.env

# 2. Verify vault contents
ansible-vault view deployment/group_vars/vault.yml \
  --vault-password-file ~/.vault_pass

# 3. Deploy with vault
./scripts/app-deploy.sh update --vault-password-file ~/.vault_pass

# 4. Delete secrets.env
rm secrets.env

# 5. Confirm application works
curl https://yourdomain.com/health
```

---

**Version:** 5.0  
**Last Updated:** February 8, 2026  
**Next Review:** May 2026

