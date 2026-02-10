#!/bin/bash
#
# Sync Ansible Vault to AWS Secrets Manager
# Extracts secrets from encrypted vault and uploads to Secrets Manager
#
# Usage: ./secret-sync-vault.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SECRET_NAME="${SECRET_NAME:-app-item-listing-tool/production}"
VAULT_FILE="$DEPLOYMENT_DIR/group_vars/production/vault.yml"
VAULT_PASS_FILE="${VAULT_PASSWORD_FILE:-$HOME/.vault_pass}"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Sync Vault to Secrets Manager          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo

# Check files exist
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${RED}✗ Vault file not found: $VAULT_FILE${NC}"
    exit 1
fi

if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${RED}✗ Vault password file not found: $VAULT_PASS_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}▶ Decrypting vault...${NC}"

# Decrypt vault and extract secrets
VAULT_CONTENT=$(ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" 2>/dev/null)

if [ -z "$VAULT_CONTENT" ]; then
    echo -e "${RED}✗ Failed to decrypt vault${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Vault decrypted${NC}"
echo

# Extract values and build JSON
echo -e "${BLUE}▶ Extracting secrets...${NC}"

extract_value() {
    local key="$1"
    echo "$VAULT_CONTENT" | grep "^vault_${key}:" | sed 's/^vault_.*: *"\?\(.*\)"\?$/\1/' | tr -d '"' | sed 's/ *$//'
}

# Build secrets JSON
SECRETS_JSON=$(cat <<EOF
{
  "SECRET_KEY": "$(extract_value secret_key)",
  "APP_SECRET_TOKEN": "$(extract_value app_secret_token)",
  "AWS_REGION": "$(extract_value aws_region)",
  "S3_BUCKET_NAME": "$(extract_value s3_bucket_name)",
  "EBAY_PRODUCTION_APP_ID": "$(extract_value ebay_production_app_id)",
  "EBAY_PRODUCTION_DEV_ID": "$(extract_value ebay_production_dev_id)",
  "EBAY_PRODUCTION_CERT_ID": "$(extract_value ebay_production_cert_id)",
  "EBAY_PRODUCTION_TOKEN": "$(extract_value ebay_production_token)",
  "EBAY_SANDBOX_APP_ID": "$(extract_value ebay_sandbox_app_id)",
  "EBAY_SANDBOX_DEV_ID": "$(extract_value ebay_sandbox_dev_id)",
  "EBAY_SANDBOX_CERT_ID": "$(extract_value ebay_sandbox_cert_id)",
  "EBAY_SANDBOX_TOKEN": "$(extract_value ebay_sandbox_token)",
  "ADMIN_USERNAME": "$(extract_value admin_username)",
  "ADMIN_PASSWORD": "$(extract_value admin_password)",
  "GITHUB_TOKEN": "$(extract_value github_token)",
  "GITHUB_REPO": "$(extract_value github_repo)",
  "GITHUB_BRANCH": "$(extract_value github_branch)",
  "CLOUDFRONT_DOMAIN": "$(extract_value cloudfront_domain)",
  "CLOUDFRONT_DISTRIBUTION_ID": "$(extract_value cloudfront_distribution_id)"
}
EOF
)

# Validate JSON
if ! echo "$SECRETS_JSON" | jq . > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to create valid JSON${NC}"
    echo "$SECRETS_JSON"
    exit 1
fi

echo -e "${GREEN}✓ Secrets extracted${NC}"

# Count non-empty secrets
SECRET_COUNT=$(echo "$SECRETS_JSON" | jq '[.[] | select(. != "")] | length')
echo -e "${BLUE}  Found $SECRET_COUNT non-empty secrets${NC}"
echo

# Upload to AWS Secrets Manager
echo -e "${BLUE}▶ Uploading to AWS Secrets Manager...${NC}"

# Check if secret exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Secret exists, updating...${NC}"

    aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRETS_JSON" > /dev/null

    echo -e "${GREEN}✓ Secret updated${NC}"
else
    echo -e "${BLUE}▶ Creating new secret...${NC}"

    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Production secrets for app-item-listing-tool (synced from Ansible Vault)" \
        --secret-string "$SECRETS_JSON" > /dev/null

    echo -e "${GREEN}✓ Secret created${NC}"
fi

echo

# Verify
echo -e "${BLUE}▶ Verifying upload...${NC}"

RETRIEVED=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --query SecretString \
    --output text)

RETRIEVED_COUNT=$(echo "$RETRIEVED" | jq '[.[] | select(. != "")] | length')

if [ "$RETRIEVED_COUNT" -eq "$SECRET_COUNT" ]; then
    echo -e "${GREEN}✓ Verification successful${NC}"
    echo -e "${GREEN}  $RETRIEVED_COUNT secrets verified${NC}"
else
    echo -e "${YELLOW}⚠ Secret count mismatch${NC}"
    echo -e "  Uploaded: $SECRET_COUNT"
    echo -e "  Retrieved: $RETRIEVED_COUNT"
fi

echo

# Summary
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Sync Complete!                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Secret Name:${NC} $SECRET_NAME"
echo -e "${BLUE}Secrets Count:${NC} $SECRET_COUNT"
echo -e "${BLUE}Last Updated:${NC} $(date)"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Restart application: ${GREEN}./scripts/app-deploy.sh restart${NC}"
echo -e "  2. Verify application: ${GREEN}curl https://yourdomain.com/health${NC}"
echo

