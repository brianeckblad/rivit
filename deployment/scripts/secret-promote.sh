#!/bin/bash
#
# Promote Secret Script
# Promotes AWSPENDING secret version to AWSCURRENT
#
# Usage: ./promote-secret.sh [version-id]
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
ROTATION_INFO="$DEPLOYMENT_DIR/.secret-rotation-info"

# Get version ID from argument or rotation info file
if [ -n "$1" ]; then
    VERSION_ID="$1"
elif [ -f "$ROTATION_INFO" ]; then
    VERSION_ID=$(grep "^NEW_VERSION_ID=" "$ROTATION_INFO" | cut -d= -f2)
else
    echo -e "${RED}✗ No version ID provided${NC}"
    echo
    echo "Usage: $0 [version-id]"
    echo
    echo "Or run after rotate-secret.sh to use saved version ID"
    exit 1
fi

if [ -z "$VERSION_ID" ]; then
    echo -e "${RED}✗ No version ID found${NC}"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Promote Secret to AWSCURRENT         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${BLUE}Secret:${NC} $SECRET_NAME"
echo -e "${BLUE}Version:${NC} $VERSION_ID"
echo

# Confirm
read -p "Promote this version to AWSCURRENT? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Aborted${NC}"
    exit 0
fi

# Get current AWSCURRENT version (for rollback info)
echo -e "${BLUE}▶ Getting current AWSCURRENT version...${NC}"

CURRENT_VERSION=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --query 'VersionIdsToStages.*.{Version:@.VersionId, Stages:@.Stages}' \
    --output json | \
    jq -r '.[] | select(.Stages[] == "AWSCURRENT") | .Version' | head -1)

echo -e "${GREEN}✓ Current version: $CURRENT_VERSION${NC}"
echo

# Promote AWSPENDING to AWSCURRENT
echo -e "${BLUE}▶ Promoting version to AWSCURRENT...${NC}"

aws secretsmanager update-secret-version-stage \
    --secret-id "$SECRET_NAME" \
    --version-stage AWSCURRENT \
    --move-to-version-id "$VERSION_ID" \
    --remove-from-version-id "$CURRENT_VERSION"

echo -e "${GREEN}✓ Version promoted to AWSCURRENT${NC}"
echo

# Verify
echo -e "${BLUE}▶ Verifying promotion...${NC}"

VERIFIED_VERSION=$(aws secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --query 'VersionIdsToStages.*.{Version:@.VersionId, Stages:@.Stages}' \
    --output json | \
    jq -r '.[] | select(.Stages[] == "AWSCURRENT") | .Version' | head -1)

if [ "$VERIFIED_VERSION" = "$VERSION_ID" ]; then
    echo -e "${GREEN}✓ Promotion verified${NC}"
else
    echo -e "${RED}✗ Promotion verification failed${NC}"
    echo -e "  Expected: $VERSION_ID"
    echo -e "  Got: $VERIFIED_VERSION"
    exit 1
fi

echo

# Update rotation info
if [ -f "$ROTATION_INFO" ]; then
    sed -i '' "s/STATUS=.*/STATUS=COMPLETED/" "$ROTATION_INFO" 2>/dev/null || \
    sed -i "s/STATUS=.*/STATUS=COMPLETED/" "$ROTATION_INFO"
    echo "PROMOTED_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$ROTATION_INFO"
    echo "OLD_VERSION_ID=$CURRENT_VERSION" >> "$ROTATION_INFO"
fi

# Summary
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Promotion Complete!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo

echo -e "${BLUE}1. Restart application to ensure new secret is loaded:${NC}"
echo -e "   ${GREEN}./scripts/app-deploy.sh restart${NC}"
echo

echo -e "${BLUE}2. Verify application is working:${NC}"
echo -e "   ${GREEN}curl https://yourdomain.com/health${NC}"
echo

echo -e "${BLUE}3. Clean up vault file:${NC}"
echo -e "   ${GREEN}ansible-vault edit group_vars/production/vault.yml --vault-password-file ~/.vault_pass${NC}"
echo -e "   ${YELLOW}# Move vault_<key>_new value to vault_<key>${NC}"
echo -e "   ${YELLOW}# Remove vault_<key>_new line${NC}"
echo

echo -e "${BLUE}4. Commit vault changes:${NC}"
echo -e "   ${GREEN}git add group_vars/production/vault.yml${NC}"
echo -e "   ${GREEN}git commit -m 'Complete secret rotation'${NC}"
echo -e "   ${GREEN}git push${NC}"
echo

echo -e "${BLUE}5. (Optional) Delete old version:${NC}"
echo -e "   Wait 7-30 days, then:"
echo -e "   ${YELLOW}aws secretsmanager delete-secret --secret-id $SECRET_NAME --version-id $CURRENT_VERSION --force-delete-without-recovery${NC}"
echo

echo -e "${GREEN}✓ Rotation completed successfully${NC}"
echo

