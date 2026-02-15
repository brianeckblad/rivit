#!/bin/bash
#
# Migrate from secrets.env to Ansible Vault
# Converts plaintext secrets.env to encrypted vault.yml
#
# Usage: ./migrate-to-vault.sh [secrets.env]
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the app name getter function
source "$SCRIPT_DIR/lib/get_app_name.sh"

# Get app name from config (use as default if not in secrets file)
DEFAULT_APP_NAME=$(get_app_name 2>/dev/null || echo "app_name")

SECRETS_FILE="${1:-$DEPLOYMENT_DIR/secrets.env}"
VAULT_FILE="$DEPLOYMENT_DIR/group_vars/production/vault.yml"
VAULT_PASS_FILE="${VAULT_PASSWORD_FILE:-$HOME/.vault_pass}"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Migrate secrets.env to Ansible Vault   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo

# Check secrets.env exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}✗ Secrets file not found: $SECRETS_FILE${NC}"
    echo
    echo "Usage: $0 [secrets-file]"
    exit 1
fi

echo -e "${BLUE}Source:${NC} $SECRETS_FILE"
echo -e "${BLUE}Target:${NC} $VAULT_FILE"
echo

# Check if vault already exists
if [ -f "$VAULT_FILE" ]; then
    echo -e "${YELLOW}⚠ Vault file already exists!${NC}"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted${NC}"
        exit 0
    fi

    # Backup existing vault
    BACKUP_FILE="${VAULT_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$VAULT_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Existing vault backed up to: $BACKUP_FILE${NC}"
    echo
fi

# Create vault password if doesn't exist
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${YELLOW}⚠ Vault password file not found${NC}"
    echo -e "${BLUE}▶ Creating new vault password...${NC}"

    # Generate secure password
    VAULT_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    echo "$VAULT_PASSWORD" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"

    echo -e "${GREEN}✓ Vault password created: $VAULT_PASS_FILE${NC}"
    echo -e "${YELLOW}  Keep this file secure! It's needed to decrypt the vault.${NC}"
    echo
fi

# Load secrets from file
echo -e "${BLUE}▶ Reading secrets from $SECRETS_FILE...${NC}"

set -a
source "$SECRETS_FILE"
set +a

echo -e "${GREEN}✓ Secrets loaded${NC}"
echo

# Create temporary unencrypted vault file
TEMP_VAULT="/tmp/vault-$$.yml"

echo -e "${BLUE}▶ Creating vault content...${NC}"

cat > "$TEMP_VAULT" << EOF
---
# Production Secrets (Ansible Vault Encrypted)
# Generated from secrets.env on $(date)
#
# Edit with: ansible-vault edit group_vars/production/vault.yml --vault-password-file ~/.vault_pass
# View with: ansible-vault view group_vars/production/vault.yml --vault-password-file ~/.vault_pass

# Application Secrets
vault_secret_key: "${SECRET_KEY:-}"
vault_app_secret_token: "${APP_SECRET_TOKEN:-}"

# AWS Configuration
vault_aws_region: "${AWS_REGION:-us-east-1}"
vault_s3_bucket_name: "${S3_BUCKET_NAME:-}"

# eBay Production Credentials
vault_ebay_production_app_id: "${EBAY_PRODUCTION_APP_ID:-}"
vault_ebay_production_dev_id: "${EBAY_PRODUCTION_DEV_ID:-}"
vault_ebay_production_cert_id: "${EBAY_PRODUCTION_CERT_ID:-}"
vault_ebay_production_token: "${EBAY_PRODUCTION_TOKEN:-}"

# eBay Sandbox Credentials
vault_ebay_sandbox_app_id: "${EBAY_SANDBOX_APP_ID:-}"
vault_ebay_sandbox_dev_id: "${EBAY_SANDBOX_DEV_ID:-}"
vault_ebay_sandbox_cert_id: "${EBAY_SANDBOX_CERT_ID:-}"
vault_ebay_sandbox_token: "${EBAY_SANDBOX_TOKEN:-}"

# Admin Credentials
vault_admin_username: "${ADMIN_USERNAME:-admin}"
vault_admin_password: "${ADMIN_PASSWORD:-}"

# GitHub Deployment
vault_github_token: "${GITHUB_TOKEN:-}"
vault_github_repo: "${GITHUB_REPO:-}"
vault_github_branch: "${GITHUB_BRANCH:-main}"

# CloudFront Configuration
vault_cloudfront_domain: "${CLOUDFRONT_DOMAIN:-}"
vault_cloudfront_distribution_id: "${CLOUDFRONT_DISTRIBUTION_ID:-}"

# Instance Name
vault_instance_name: "${INSTANCE_NAME:-$DEFAULT_APP_NAME}"
EOF

echo -e "${GREEN}✓ Vault content created${NC}"
echo

# Count secrets
TOTAL_SECRETS=$(grep -c "^vault_" "$TEMP_VAULT" || true)
NON_EMPTY=$(grep "^vault_.*: \"[^\"]\+\"" "$TEMP_VAULT" | wc -l || true)

echo -e "${BLUE}  Total keys: $TOTAL_SECRETS${NC}"
echo -e "${BLUE}  Non-empty: $NON_EMPTY${NC}"
echo

# Ensure group_vars directory exists
mkdir -p "$(dirname "$VAULT_FILE")"

# Encrypt vault file
echo -e "${BLUE}▶ Encrypting vault...${NC}"

if ! ansible-vault encrypt "$TEMP_VAULT" \
    --vault-password-file "$VAULT_PASS_FILE" \
    --output "$VAULT_FILE" 2>/dev/null; then
    echo -e "${RED}✗ Failed to encrypt vault${NC}"
    rm -f "$TEMP_VAULT"
    exit 1
fi

# Clean up temp file
rm -f "$TEMP_VAULT"

echo -e "${GREEN}✓ Vault encrypted${NC}"
echo

# Verify encryption
echo -e "${BLUE}▶ Verifying vault...${NC}"

if ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Vault verified${NC}"
else
    echo -e "${RED}✗ Vault verification failed${NC}"
    exit 1
fi

echo

# Summary
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Migration Complete!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Vault File:${NC} $VAULT_FILE"
echo -e "${BLUE}Password File:${NC} $VAULT_PASS_FILE"
echo -e "${BLUE}Secrets:${NC} $NON_EMPTY non-empty out of $TOTAL_SECRETS total"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo

echo -e "${BLUE}1. Verify vault contents:${NC}"
echo -e "   ${GREEN}ansible-vault view $VAULT_FILE --vault-password-file $VAULT_PASS_FILE${NC}"
echo

echo -e "${BLUE}2. Sync to AWS Secrets Manager:${NC}"
echo -e "   ${GREEN}./scripts/secret-sync-vault.sh${NC}"
echo

echo -e "${BLUE}3. Test deployment:${NC}"
echo -e "   ${GREEN}./scripts/app-deploy.sh update --vault-password-file $VAULT_PASS_FILE${NC}"
echo

echo -e "${BLUE}4. Delete secrets.env (IMPORTANT!):${NC}"
echo -e "   ${YELLOW}rm $SECRETS_FILE${NC}"
echo -e "   ${YELLOW}# Make sure vault is working first!${NC}"
echo

echo -e "${BLUE}5. Add vault to git:${NC}"
echo -e "   ${GREEN}git add $VAULT_FILE${NC}"
echo -e "   ${GREEN}git commit -m 'Add encrypted vault (safe to commit)'${NC}"
echo -e "   ${GREEN}git push${NC}"
echo

echo -e "${BLUE}6. Ensure .vault_pass is in .gitignore:${NC}"
echo -e "   ${GREEN}echo '.vault_pass' >> .gitignore${NC}"
echo

echo -e "${GREEN}✓ Migration completed successfully${NC}"
echo

