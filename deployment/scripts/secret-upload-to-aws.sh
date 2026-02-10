#!/bin/bash
#
# AWS Secrets Manager Setup
# Uploads secrets from a file to AWS Secrets Manager
#
# Usage: ./secrets-manager-setup.sh [secrets-file]
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SECRETS_FILE="${1:-secrets.env}"

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}✗ Secrets file not found: $SECRETS_FILE${NC}"
    echo
    echo "Usage: $0 [secrets-file]"
    echo
    echo "Example secrets file format:"
    echo "  SECRET_KEY=your-secret-key"
    echo "  EBAY_PRODUCTION_APP_ID=your-app-id"
    echo "  ..."
    exit 1
fi

echo -e "${BLUE}▶ Loading secrets from: $SECRETS_FILE${NC}"

# Load secrets
set -a
source "$SECRETS_FILE"
set +a

# Get instance name
INSTANCE_NAME="${INSTANCE_NAME:-app-item-listing-tool}"
SECRET_NAME="${INSTANCE_NAME}/production"

# Build JSON
SECRETS_JSON=$(cat <<EOF
{
  "SECRET_KEY": "${SECRET_KEY:-}",
  "AWS_REGION": "${AWS_REGION:-us-east-1}",
  "S3_BUCKET_NAME": "${S3_BUCKET_NAME:-}",
  "EBAY_PRODUCTION_APP_ID": "${EBAY_PRODUCTION_APP_ID:-}",
  "EBAY_PRODUCTION_DEV_ID": "${EBAY_PRODUCTION_DEV_ID:-}",
  "EBAY_PRODUCTION_CERT_ID": "${EBAY_PRODUCTION_CERT_ID:-}",
  "EBAY_PRODUCTION_TOKEN": "${EBAY_PRODUCTION_TOKEN:-}",
  "EBAY_SANDBOX_APP_ID": "${EBAY_SANDBOX_APP_ID:-}",
  "EBAY_SANDBOX_DEV_ID": "${EBAY_SANDBOX_DEV_ID:-}",
  "EBAY_SANDBOX_CERT_ID": "${EBAY_SANDBOX_CERT_ID:-}",
  "EBAY_SANDBOX_TOKEN": "${EBAY_SANDBOX_TOKEN:-}",
  "ADMIN_USERNAME": "${ADMIN_USERNAME:-}",
  "ADMIN_PASSWORD": "${ADMIN_PASSWORD:-}",
  "APP_SECRET_TOKEN": "${APP_SECRET_TOKEN:-}",
  "GITHUB_TOKEN": "${GITHUB_TOKEN:-}",
  "GITHUB_REPO": "${GITHUB_REPO:-}",
  "GITHUB_BRANCH": "${GITHUB_BRANCH:-main}",
  "CLOUDFRONT_DOMAIN": "${CLOUDFRONT_DOMAIN:-}"
}
EOF
)

echo -e "${BLUE}▶ Uploading to AWS Secrets Manager...${NC}"

# Check if secret exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Secret already exists, updating...${NC}"
    aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRETS_JSON"
else
    echo -e "${BLUE}▶ Creating new secret...${NC}"
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Production secrets for $INSTANCE_NAME" \
        --secret-string "$SECRETS_JSON"
fi

echo -e "${GREEN}✓ Secrets uploaded successfully${NC}"
echo -e "${GREEN}  Secret Name: $SECRET_NAME${NC}"
echo

echo -e "${YELLOW}To retrieve secrets:${NC}"
echo -e "  aws secretsmanager get-secret-value --secret-id $SECRET_NAME"
echo

echo -e "${YELLOW}To update a specific value:${NC}"
echo -e "  aws secretsmanager put-secret-value \\"
echo -e "    --secret-id $SECRET_NAME \\"
echo -e "    --secret-string '{\"SECRET_KEY\": \"new-value\"}'"
echo

