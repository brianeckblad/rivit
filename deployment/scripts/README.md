# Deployment Scripts Reference

**Last Updated:** February 8, 2026

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

