# Application Secrets Management - .env vs AWS Secrets Manager

**Date:** February 25, 2026  
**Status:** ✅ UPDATED

---

## Architecture

### Secrets Storage

| Location | Purpose | When Used | Security |
|----------|---------|-----------|----------|
| **Ansible Vault** (`vault.yml`) | Deployment configuration secrets | During deployment (Ansible playbooks) | ✅ Encrypted at rest |
| **AWS Secrets Manager** | Runtime application secrets | Application running on EC2 | ✅ Encrypted, IAM role-based access |
| **.env file** | Local development ONLY | Development on your machine | ⚠️ No encryption, for dev only |

---

## Development vs Production

### Local Development (.env file)

For local development, you can use a `.env` file:

```bash
# .env (local development only - NOT committed to git)
FLASK_SECRET_KEY=dev-secret-key-here
FLASK_ENV=development
AWS_ACCESS_KEY_ID=your-dev-access-key
AWS_SECRET_ACCESS_KEY=your-dev-secret-key
EBAY_ENVIRONMENT=sandbox
EBAY_SANDBOX_APP_ID=your-sandbox-app-id
```

**Important:**
- Add `.env` to `.gitignore` (it is already)
- Never commit real secrets
- Use sandbox credentials for testing

### Production Deployment (AWS Secrets Manager)

On deployed servers, secrets come from **AWS Secrets Manager**, NOT from `.env` files:

1. **Ansible Vault** (deployment time):
   - Contains secrets for deployment
   - Vault playbook syncs them to AWS Secrets Manager
   - Vault is encrypted and safe to commit

2. **AWS Secrets Manager** (runtime):
   - Application reads secrets from here
   - EC2 instance uses IAM role (no credentials in .env)
   - Secrets are encrypted and rotated automatically

3. **No .env file on server**:
   - Application doesn't need local .env
   - All secrets come from AWS Secrets Manager
   - More secure - no local file with secrets

---

## Secrets in Ansible Vault

All application secrets are defined in `vault.yml`:

```yaml
# vault.yml (encrypted)
flask_secret_key: "generated-secret-key"
flask_env: "production"
flask_port: "8000"

ebay_environment: "production"
ebay_production_app_id: "your-app-id"
ebay_production_token: "your-token"
ebay_verification_token: "your-verification-token"

app_default_username: "admin"
app_default_password: "strong-password"

vault_sns_topic_arn: "arn:aws:sns:..."
```

**Why in vault?**
- Encrypted at rest
- Version controlled (safe because encrypted)
- Used during deployment to create AWS Secrets Manager secret
- Playbooks automatically decrypt them

---

## Deployment Flow

### 1. Setup Phase (before deployment)

```
Edit vault.yml with your secrets
↓
Encrypt it: ansible-vault encrypt vault.yml
↓
Now safe to commit (encrypted content only)
```

### 2. Deployment Phase

```
Ansible playbook runs
↓
Decrypts vault.yml (using ~/.vault_pass or prompts you)
↓
Extracts vault variables
↓
Creates AWS Secrets Manager secret with those values
↓
EC2 instance configured with IAM role to read from Secrets Manager
```

### 3. Runtime Phase

```
Application starts on EC2
↓
Reads secrets from AWS Secrets Manager via IAM role
↓
No .env file needed
↓
No credentials in application code
```

---

## .env File on Deployment Server

**Minimal .env on deployed server** (if needed at all):

```bash
# /rampe/.env (MINIMAL - most secrets come from AWS Secrets Manager)
FLASK_ENV=production
PORT=8000

# AWS credentials NOT here - using IAM role instead
# Database credentials NOT here - using AWS Secrets Manager
# API keys NOT here - using AWS Secrets Manager
```

**Most values are fetched from AWS Secrets Manager at runtime, not from .env**

---

## Secrets Added to vault.yml

The following secrets from `.env.example` are now in encrypted `vault.yml`:

### Flask Configuration
- `flask_secret_key` - Session encryption, CSRF protection
- `flask_env` - development or production
- `flask_port` - Application port

### eBay Configuration
- `ebay_environment` - sandbox or production
- `ebay_sandbox_app_id`, `ebay_sandbox_cert_id`, etc.
- `ebay_production_app_id`, `ebay_production_cert_id`, etc.
- `ebay_verification_token` - For marketplace endpoints

### Application Credentials
- `app_default_username` - Initial admin username
- `app_default_password` - Initial admin password

### AWS Configuration
- `vault_sns_topic_arn` - Optional SNS topic for alerts

---

## How the Application Gets Secrets

### At Deployment Time

1. Playbook decrypts vault.yml
2. Playbook reads variables
3. Playbook creates AWS Secrets Manager secret with those values
4. Playbook configures EC2 instance IAM role
5. Playbook deploys application

### At Runtime (Application Starting)

```python
# Application code
import boto3

secrets_manager = boto3.client('secretsmanager')
secret = secrets_manager.get_secret_value(SecretId='rampe/secrets')

# Now application has all secrets from AWS Secrets Manager
# No need for .env file!
```

---

## Security Benefits

✅ **Encrypted Vault**
- All secrets encrypted with Ansible Vault
- Safe to commit to Git (content is encrypted)

✅ **AWS Secrets Manager**
- Secrets encrypted in AWS
- Access controlled by IAM role
- No credentials in application code
- Automatic rotation (if configured)

✅ **No .env on Server**
- No local file with secrets
- No risk of accidental exposure
- Centralized secret management

✅ **IAM Role Based**
- EC2 instance uses role-based access
- No AWS access keys stored anywhere
- Automatic credential rotation by AWS

---

## Updating Secrets

### During Development
```bash
# Edit .env locally
FLASK_SECRET_KEY=your-new-key
# Restart application
```

### After Deployment
```bash
# Decrypt vault
ansible-vault decrypt vault.yml --vault-password-file ~/.vault_pass

# Edit values
nano vault.yml

# Re-encrypt
ansible-vault encrypt vault.yml --vault-password-file ~/.vault_pass

# Run playbook to sync to AWS Secrets Manager
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass

# Or manually update in AWS:
aws secretsmanager update-secret --secret-id rampe/secrets --secret-string '{...}'
```

---

## Summary

| Phase | Location | Format | Encrypted |
|-------|----------|--------|-----------|
| **Development** | .env locally | Plain text | No (dev only) |
| **Deployment Setup** | vault.yml | YAML + Vault | ✅ Yes |
| **Deployment Sync** | AWS Secrets Manager | JSON | ✅ Yes |
| **Runtime** | AWS Secrets Manager | AWS managed | ✅ Yes |

**Best Practice:**
1. Store secrets in vault.yml (encrypted)
2. Deploy with Ansible (syncs to AWS Secrets Manager)
3. Application reads from AWS Secrets Manager (no .env needed)
4. .env file only for local development


