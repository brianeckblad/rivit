#!/bin/bash
# Generate eBay Verification Token
# This token is required for marketplace account deletion endpoint validation
# Must be between 32-80 characters

set -e

echo "======================================"
echo "eBay Verification Token Generator"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✓ Created .env from .env.example"
    else
        echo "❌ Error: .env.example not found"
        exit 1
    fi
fi

# Check if token already exists
if grep -q "^EBAY_VERIFICATION_TOKEN=" .env; then
    EXISTING_TOKEN=$(grep "^EBAY_VERIFICATION_TOKEN=" .env | cut -d'=' -f2)

    if [ ! -z "$EXISTING_TOKEN" ] && [ "$EXISTING_TOKEN" != "your-64-character-token-here" ]; then
        echo "✓ eBay verification token already exists in .env"
        echo "  Token: ${EXISTING_TOKEN:0:16}...${EXISTING_TOKEN: -16}"
        echo ""
        echo "  Keep existing token? (Y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            echo "✓ Keeping existing token"
            exit 0
        fi
    fi
fi

# Generate new token (64 characters)
echo "🔐 Generating new 64-character verification token..."
NEW_TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(48)[:64])")

# Update or add token to .env
if grep -q "^EBAY_VERIFICATION_TOKEN=" .env; then
    # Token line exists, replace it
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^EBAY_VERIFICATION_TOKEN=.*/EBAY_VERIFICATION_TOKEN=$NEW_TOKEN/" .env
    else
        # Linux
        sed -i "s/^EBAY_VERIFICATION_TOKEN=.*/EBAY_VERIFICATION_TOKEN=$NEW_TOKEN/" .env
    fi
    echo "✓ Updated EBAY_VERIFICATION_TOKEN in .env"
else
    # Token line doesn't exist, append it
    echo "" >> .env
    echo "# eBay Marketplace Account Deletion" >> .env
    echo "EBAY_VERIFICATION_TOKEN=$NEW_TOKEN" >> .env
    echo "✓ Added EBAY_VERIFICATION_TOKEN to .env"
fi

echo ""
echo "======================================"
echo "✅ Token Generated Successfully"
echo "======================================"
echo ""
echo "Your eBay Verification Token:"
echo "$NEW_TOKEN"
echo ""
echo "⚠️  IMPORTANT:"
echo "1. This token has been saved to your .env file"
echo "2. Copy this token to eBay Developer Portal:"
echo "   - Go to: https://developer.ebay.com/my/keys"
echo "   - Navigate to your app settings"
echo "   - Under 'Marketplace Account Deletion', paste this token"
echo ""
echo "3. Your deletion endpoint URL is:"
echo "   https://app.badartink.com/api/ebay/marketplace-account-deletion"
echo ""
echo "4. Test the endpoint after setup:"
echo "   curl 'https://app.badartink.com/api/ebay/marketplace-account-deletion?challenge_code=test123'"
echo ""
echo "Note: This token persists across deployments and will NOT be regenerated"
echo "      unless you explicitly run this script again."
echo ""
