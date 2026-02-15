# Deployment Scripts Reference

**Last Updated:** February 14, 2026

---

## 📝 Manual Deployment Helpers

**These scripts generate configuration files with proper variable substitution for manual deployment:**

### `manual-generate-systemd.sh`
**Generate systemd service file**

```bash
cd deployment/scripts
./manual-generate-systemd.sh
```

**What it does:**
- Reads your `app_name` from `deployment/group_vars/all.yml`
- Generates `deployment/{app_name}.service` with ALL variables substituted
- Includes security hardening (NoNewPrivileges, ProtectSystem, etc.)
- Provides exact commands to copy and install on server

**Output:** Ready-to-use systemd service file

**Why:** Manual deployment had placeholders like `{app_name}` that users had to replace manually (error-prone!)

### `manual-generate-nginx.sh`
**Generate nginx configuration file**

```bash
cd deployment/scripts
./manual-generate-nginx.sh
# Enter domain name (or press Enter for IP-based access)
```

**What it does:**
- Reads your `app_name` and `admin_user` from configuration
- Prompts for domain name (optional)
- Generates `deployment/{app_name}-nginx.conf` with ALL variables substituted
- Includes rate limiting, security headers, static files, proxy settings
- Provides exact commands to copy and install on server

**Output:** Ready-to-use nginx configuration file

**Why:** Nginx config had many placeholders - this ensures nothing is missed

---

## 🔧 How Configuration Works

**All scripts automatically read `app_name` from your configuration file.**

### Quick Start
1. Set your app name once:
   ```bash
   vim deployment/group_vars/all.yml
   # Set: app_name: myapp
   ```

2. Run any script - it automatically uses your `app_name`:
   ```bash
   ./app-deploy.sh update        # Uses "myapp"
   ./ssl-setup.sh                # Uses "myapp"  
   ./app-hard-restart.sh         # Uses "myapp"
   ```

### How It Works
- **Config File:** `group_vars/all.yml` (single source of truth)
- **Helper:** `scripts/lib/get_app_name.sh` (reads YAML config)
- **All Scripts:** Automatically source the helper and read app_name

### Validation
Scripts fail with helpful message if `app_name` not configured:
```bash
ERROR: app_name not set in deployment/group_vars/all.yml (currently: CHANGEME)
```

**No manual script updates needed!** ✅

---

## Script Naming Convention

All scripts follow a consistent prefix-based naming convention:

- **`infra-*`** - Infrastructure setup (AWS resources)
- **`app-*`** - Application deployment and management
- **`secret-*`** - Secret management (vault, AWS Secrets Manager)
- **`ssl-*`** - SSL/TLS certificate management
- **`util-*`** - Utility scripts and tools

---

## Infrastructure Scripts

### `infra-complete-setup.sh`
**Purpose:** Complete AWS infrastructure setup in one command  
**Creates:** IAM role, EC2, VPC, CloudFront, WAF, Secrets Manager, S3  
**Duration:** 15-20 minutes  
**Usage:**
```bash
cd deployment
./scripts/infra-complete-setup.sh [secrets-file]
```

**Note:** This is the recommended way to deploy. It creates everything automatically.

### `iam-role-setup.sh`
**Purpose:** Create IAM role for EC2 instance  
**Creates:** IAM role, instance profile, S3/Secrets Manager policies  
**Duration:** 1-2 minutes  
**Usage:**
```bash
cd deployment/scripts
./iam-role-setup.sh <role-name> <s3-bucket> <region>
```

**Note:** Called automatically by `infra-complete-setup.sh`

### `ec2-create-instance.sh`
**Purpose:** Create EC2 instance with VPC and networking  
**Creates:** VPC, subnet, internet gateway, security group, EC2 instance  
**Duration:** 3-5 minutes  
**Usage:**
```bash
export INSTANCE_NAME="my-app"
export INSTANCE_TYPE="t3.nano"
export IAM_INSTANCE_PROFILE="my-role-profile"
./scripts/ec2-create-instance.sh
```

**Note:** Called automatically by `infra-complete-setup.sh`

---

## Application Scripts

### `app-deploy.sh`
**Purpose:** Main deployment script for all deployment tasks  
**Commands:**
- `setup` - Initial deployment
- `update` - Deploy code changes
- `restart` - Restart application
- `logs` - View logs
- `status` - Check status
- `rollback <hash>` - Rollback to commit

**Usage:**
```bash
cd deployment
./scripts/app-deploy.sh setup           # Initial setup
./scripts/app-deploy.sh update          # Update code
./scripts/app-deploy.sh restart         # Restart app
./scripts/app-deploy.sh logs            # View logs
./scripts/app-deploy.sh status          # Check status
./scripts/app-deploy.sh rollback abc123 # Rollback
```

### `app-hard-restart.sh`
**Purpose:** Force restart application (kills and restarts)  
**Usage:**
```bash
cd deployment
./scripts/app-hard-restart.sh
```

---

## Secret Management Scripts

### `secret-sync-vault.sh`
**Purpose:** Sync Ansible Vault to AWS Secrets Manager  
**When to use:** After editing vault, before deployment  
**Usage:**
```bash
cd deployment
./scripts/secret-sync-vault.sh
```

### `secret-rotate.sh`
**Purpose:** Create AWSPENDING version for rotation  
**Process:** Zero-downtime secret rotation  
**Usage:**
```bash
cd deployment
./scripts/secret-rotate.sh <secret-key>

# Example:
./scripts/secret-rotate.sh ebay_production_token
```

### `secret-promote.sh`
**Purpose:** Promote AWSPENDING to AWSCURRENT  
**When to use:** After testing new secret  
**Usage:**
```bash
cd deployment
./scripts/secret-promote.sh [version-id]
```

### `secret-upload-to-aws.sh`
**Purpose:** Upload secrets from file to AWS Secrets Manager  
**Usage:**
```bash
cd deployment
./scripts/secret-upload-to-aws.sh [secrets-file]
```

### `secret-migrate-to-vault.sh`
**Purpose:** Convert secrets.env to encrypted vault.yml  
**Usage:**
```bash
cd deployment
./scripts/secret-migrate-to-vault.sh [secrets.env]
```

---

## SSL/Certificate Scripts

### `ssl-setup.sh`
**Purpose:** Setup SSL certificate with Let's Encrypt  
**Requirements:** DNS must point to server  
**Usage:**
```bash
cd deployment
./scripts/ssl-setup.sh
```

### `ssl-add-config.sh`
**Purpose:** Add SSL configuration to existing Nginx setup  
**Usage:**
```bash
cd deployment
./scripts/ssl-add-config.sh
```

---

## Utility Scripts

### `util-generate-ebay-token.sh`
**Purpose:** Generate eBay OAuth token  
**Usage:**
```bash
cd deployment/scripts
./util-generate-ebay-token.sh
```

### `util-check-comic-images.py`
**Purpose:** Check image URLs for specific SKU  
**Usage:**
```bash
cd deployment/scripts
./util-check-comic-images.py <SKU>
```

### `util-fix-missing-thumbnails.py`
**Purpose:** Fix missing thumbnail images  
**Usage:**
```bash
cd deployment/scripts
./util-fix-missing-thumbnails.py
```

### `util-generate-page-images.py`
**Purpose:** Generate page mockup images for analytics  
**Usage:**
```bash
cd deployment/scripts
./util-generate-page-images.py
```

### `util-validate-csv-schema.py`
**Purpose:** Validate CSV schema and data  
**Usage:**
```bash
cd deployment/scripts
./util-validate-csv-schema.py
```

---

## Quick Reference

| Task | Script |
|------|--------|
| **Complete AWS setup** | `infra-complete-setup.sh` |
| **Deploy application** | `app-deploy.sh setup` |
| **Update code** | `app-deploy.sh update` |
| **View logs** | `app-deploy.sh logs` |
| **Restart app** | `app-deploy.sh restart` |
| **Sync secrets** | `secret-sync-vault.sh` |
| **Rotate secret** | `secret-rotate.sh <key>` then `secret-promote.sh` |
| **Setup SSL** | `ssl-setup.sh` |

---

**Version:** 5.0  
**Last Updated:** February 8, 2026

