#!/bin/bash
# Setup local development configuration
# This creates local override files that are ignored by Git

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"
PRODUCTION_DIR="$GROUP_VARS_DIR/production"

echo "=================================================="
echo "Local Development Configuration Setup"
echo "=================================================="
echo ""
echo "This will create local override files that are"
echo "automatically ignored by Git."
echo ""

# Check if we're in the right directory
if [ ! -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo "❌ Error: Cannot find group_vars/all.yml"
    echo "   Please run this script from: deployment/scripts/"
    exit 1
fi

# Function to create local override file
create_local_override() {
    local source_file="$1"
    local dest_file="$2"
    local file_description="$3"

    if [ -f "$dest_file" ]; then
        echo "⚠️  $dest_file already exists"
        read -p "   Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Skipped."
            return
        fi
    fi

    echo "📝 Creating $file_description..."
    cp "$source_file" "$dest_file"
    echo "   ✅ Created: $dest_file"
}

# Create all.local.yml
echo ""
echo "Step 1: Create all.local.yml (main config override)"
echo "-----------------------------------------------------"
create_local_override \
    "$GROUP_VARS_DIR/all.yml" \
    "$GROUP_VARS_DIR/all.local.yml" \
    "main config override"

# Create production.local.yml (optional)
echo ""
echo "Step 2: Create production.local.yml (environment override)"
echo "-----------------------------------------------------"
if [ -f "$GROUP_VARS_DIR/production.yml" ]; then
    create_local_override \
        "$GROUP_VARS_DIR/production.yml" \
        "$GROUP_VARS_DIR/production.local.yml" \
        "production environment override"
fi

# Create vault.yml from example
echo ""
echo "Step 3: Create vault.yml (secrets file)"
echo "-----------------------------------------------------"
if [ -f "$PRODUCTION_DIR/vault.yml.example" ]; then
    create_local_override \
        "$PRODUCTION_DIR/vault.yml.example" \
        "$PRODUCTION_DIR/vault.yml" \
        "secrets vault file"
else
    echo "⚠️  vault.yml.example not found, skipping..."
fi

# Summary
echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Local override files created (ignored by Git):"
echo ""

if [ -f "$GROUP_VARS_DIR/all.local.yml" ]; then
    echo "  📄 group_vars/all.local.yml"
    echo "     → Edit this for your app name, domain, etc."
fi

if [ -f "$GROUP_VARS_DIR/production.local.yml" ]; then
    echo "  📄 group_vars/production.local.yml"
    echo "     → Edit this for production-specific settings"
fi

if [ -f "$PRODUCTION_DIR/vault.yml" ]; then
    echo "  📄 group_vars/production/vault.yml"
    echo "     → Edit this for your secrets (Git repo, S3, passwords)"
fi

echo ""
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Edit your local config files:"
echo "   cd $DEPLOYMENT_DIR"
echo "   nano group_vars/all.local.yml"
echo "   nano group_vars/production/vault.yml"
echo ""
echo "2. Create vault password file:"
echo "   echo 'your-secure-password' > ~/.vault_pass"
echo "   chmod 600 ~/.vault_pass"
echo ""
echo "3. (Optional) Encrypt your vault:"
echo "   cd $DEPLOYMENT_DIR"
echo "   ansible-vault encrypt group_vars/production/vault.yml \\"
echo "     --vault-password-file ~/.vault_pass"
echo ""
echo "4. Verify nothing is staged for commit:"
echo "   git status"
echo "   # Should show: nothing to commit"
echo ""
echo "5. Deploy your application:"
echo "   ./scripts/infra-complete-setup.sh"
echo ""
echo "📚 Documentation: docs/guides/LOCAL_DEVELOPMENT.md"
echo ""

