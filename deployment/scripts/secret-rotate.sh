#!/bin/bash
#
# Secret Rotation Script
# Rotates a secret from Ansible Vault to AWS Secrets Manager
#
# Usage: ./rotate-secrets.sh <secret-key>
# Example: ./rotate-secrets.sh ebay_production_token
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}✗ Missing secret key${NC}"
    echo
    echo "Usage: $0 <secret-key>"
    echo
    echo "Example: $0 ebay_production_token"
    echo
    echo "Process:"
    echo "  1. Add new secret to vault as 'vault_<key>_new'"
    echo "  2. Run this script to create AWSPENDING version"
    echo "  3. Test your application"
    echo "  4. If successful, run promote-secret.sh"
    exit 1
fi

SECRET_KEY="$1"
SECRET_NAME="${SECRET_NAME:-app-item-listing-tool/production}"
VAULT_FILE="$DEPLOYMENT_DIR/group_vars/production/vault.yml"
VAULT_PASS_FILE="${VAULT_PASSWORD_FILE:-$HOME/.vault_pass}"

# Check vault file exists
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${RED}✗ Vault file not found: $VAULT_FILE${NC}"
    exit 1
fi

# Check vault password file
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${RED}✗ Vault password file not found: $VAULT_PASS_FILE${NC}"
    echo "  Set VAULT_PASSWORD_FILE environment variable or create ~/.vault_pass"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Secret Rotation Process              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Secret Key:${NC} $SECRET_KEY"
echo -e "${BLUE}Vault File:${NC} $VAULT_FILE"
echo

# Get new value from vault (with _new suffix)
echo -e "${BLUE}▶ Extracting new secret from vault...${NC}"

NEW_VALUE=$(ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" 2>/dev/null | \
    grep "^vault_${SECRET_KEY}_new:" | \
    sed 's/^vault_.*_new: *"\?\(.*\)"\?$/\1/' | \
    tr -d '"' | \
    sed 's/ *$//')

if [ -z "$NEW_VALUE" ]; then
    echo -e "${RED}✗ New secret not found in vault${NC}"
    echo
    echo "Expected key: ${YELLOW}vault_${SECRET_KEY}_new${NC}"
    echo
    echo "Steps to fix:"
    echo "  1. Edit vault: ansible-vault edit $VAULT_FILE --vault-password-file $VAULT_PASS_FILE"
    echo "  2. Add: vault_${SECRET_KEY}_new: \"your-new-value\""
    echo "  3. Save and run this script again"
    exit 1
fi

echo -e "${GREEN}✓ New secret found${NC}"
echo -e "${BLUE}  Length: ${#NEW_VALUE} characters${NC}"
echo

# Get current secret from AWS Secrets Manager
echo -e "${BLUE}▶ Fetching current secret from AWS Secrets Manager...${NC}"

if ! CURRENT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --query SecretString \
    --output text 2>/dev/null); then
    echo -e "${RED}✗ Failed to fetch secret from AWS Secrets Manager${NC}"
    echo "  Make sure:"
    echo "    - AWS credentials are configured"
    echo "    - Secret exists: $SECRET_NAME"
    echo "    - You have secretsmanager:GetSecretValue permission"
    exit 1
fi

echo -e "${GREEN}✓ Current secret fetched${NC}"
echo

# Convert SECRET_KEY format (ebay_production_token → EBAY_PRODUCTION_TOKEN)
AWS_KEY=$(echo "$SECRET_KEY" | tr '[:lower:]' '[:upper:]')

# Update JSON with new value
echo -e "${BLUE}▶ Creating new secret version (AWSPENDING)...${NC}"

UPDATED_SECRET=$(echo "$CURRENT_SECRET" | jq --arg key "$AWS_KEY" --arg val "$NEW_VALUE" \
    '. + {($key): $val}')

if [ -z "$UPDATED_SECRET" ]; then
    echo -e "${RED}✗ Failed to create updated secret JSON${NC}"
    exit 1
fi

# Upload as AWSPENDING version
if ! NEW_VERSION_ID=$(aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$UPDATED_SECRET" \
    --version-stages AWSPENDING \
    --query VersionId \
    --output text 2>&1); then
    echo -e "${RED}✗ Failed to create new secret version${NC}"
    echo "$NEW_VERSION_ID"
    exit 1
fi

echo -e "${GREEN}✓ New secret version created${NC}"
echo -e "${GREEN}  Version ID: $NEW_VERSION_ID${NC}"
echo -e "${GREEN}  Stage: AWSPENDING${NC}"
echo

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Rotation Status: PENDING             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo
echo -e "${BLUE}1. Test your application with the new secret${NC}"
echo -e "   The application can fetch AWSPENDING version for testing"
echo

echo -e "${BLUE}2. If successful, promote to AWSCURRENT:${NC}"
echo -e "   ${GREEN}./scripts/promote-secret.sh $NEW_VERSION_ID${NC}"
echo

echo -e "${BLUE}3. If failed, rollback:${NC}"
echo -e "   ${YELLOW}./scripts/rollback-secret.sh${NC}"
echo

echo -e "${BLUE}4. After promotion, clean up vault:${NC}"
echo -e "   ${GREEN}ansible-vault edit $VAULT_FILE --vault-password-file $VAULT_PASS_FILE${NC}"
echo -e "   ${YELLOW}# Update vault_${SECRET_KEY} to new value${NC}"
echo -e "   ${YELLOW}# Remove vault_${SECRET_KEY}_new${NC}"
echo

# Save rotation info
ROTATION_INFO="$DEPLOYMENT_DIR/.secret-rotation-info"
cat > "$ROTATION_INFO" << EOF
SECRET_KEY=$SECRET_KEY
NEW_VERSION_ID=$NEW_VERSION_ID
ROTATION_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
STATUS=PENDING
EOF

echo -e "${GREEN}✓ Rotation info saved to: $ROTATION_INFO${NC}"
echo

