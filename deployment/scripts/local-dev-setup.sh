#!/bin/bash
# Setup local development configuration using .example file pattern
# This is the standard industry pattern for configuration management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"

echo "=================================================="
echo "Configuration Setup (.example pattern)"
echo "=================================================="
echo ""
echo "This will create your configuration files from"
echo ".example templates."
echo ""
echo "Pattern:"
echo "  .example files = Templates (tracked in Git)"
echo "  Real files     = Your configs (ignored by Git)"
echo ""

# Check if we're in the right directory
if [ ! -f "$GROUP_VARS_DIR/all.yml.example" ]; then
    echo "❌ Error: Cannot find group_vars/all.yml.example"
    echo "   Please run this script from: deployment/scripts/"
    exit 1
fi

# Function to create config from example
create_from_example() {
    local example_file="$1"
    local dest_file="$2"
    local file_description="$3"

    if [ ! -f "$example_file" ]; then
        echo "⚠️  $example_file not found, skipping..."
        return
    fi

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
    cp "$example_file" "$dest_file"
    echo "   ✅ Created: $dest_file"
}

# Create all.yml from all.yml.example
echo ""
echo "Step 1: Create all.yml (main configuration)"
echo "-----------------------------------------------------"
create_from_example \
    "$GROUP_VARS_DIR/all.yml.example" \
    "$GROUP_VARS_DIR/all.yml" \
    "main configuration"

# Create vault.yml from vault.yml.example
echo ""
echo "Step 2: Create vault.yml (secrets file)"
echo "-----------------------------------------------------"
create_from_example \
    "$GROUP_VARS_DIR/vault.yml.example" \
    "$GROUP_VARS_DIR/vault.yml" \
    "secrets vault file"

# Summary
echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration files created (ignored by Git):"
echo ""

if [ -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo "  📄 group_vars/all.yml"
    echo "     → Edit this for your app name, domain, etc."
fi

if [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    echo "  📄 group_vars/vault.yml"
    echo "     → Edit this for your secrets (Git repo, S3, passwords)"
fi

echo ""
echo "Template files (tracked in Git, receive updates):"
echo ""
echo "  📄 group_vars/all.yml.example"
echo "  📄 group_vars/vault.yml.example"
echo ""
echo "Next Steps:"
echo ""
echo "Step 3: Create vault password file (if needed)"
echo "-----------------------------------------------------"

VAULT_PASS_FILE="$HOME/.vault_pass"

if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "🔐 Creating vault password file..."
    echo "Enter a strong password for vault encryption:"
    read -s VAULT_PASSWORD
    echo "$VAULT_PASSWORD" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo "   ✅ Created: $VAULT_PASS_FILE (with 600 permissions)"
else
    echo "⚠️  Vault password file already exists at $VAULT_PASS_FILE"
fi

# Encrypt vault.yml if it exists and is not already encrypted
echo ""
echo "Step 4: Encrypt vault.yml (REQUIRED - securing secrets)"
echo "-----------------------------------------------------"

if [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    # Check if vault.yml is already encrypted
    if head -1 "$GROUP_VARS_DIR/vault.yml" | grep -q "ANSIBLE_VAULT"; then
        echo "✅ vault.yml is already encrypted"
    else
        echo "🔒 Encrypting vault.yml..."
        cd "$DEPLOYMENT_DIR"
        ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default 2>/dev/null
        echo "   ✅ vault.yml is now encrypted"
        echo "   Verify: head -1 group_vars/vault.yml"
    fi
fi

echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration files created (ignored by Git):"
echo ""

if [ -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo "  📄 group_vars/all.yml"
    echo "     → Edit this for your app name, domain, etc."
fi

if [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    # Check if encrypted
    if head -1 "$GROUP_VARS_DIR/vault.yml" | grep -q "ANSIBLE_VAULT"; then
        echo "  🔒 group_vars/vault.yml (ENCRYPTED)"
    else
        echo "  ⚠️  group_vars/vault.yml (NOT ENCRYPTED - fix this!)"
    fi
    echo "     → Edit with: ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass"
fi

echo ""
echo "Template files (tracked in Git, receive updates):"
echo ""
echo "  📄 group_vars/all.yml.example"
echo "  📄 group_vars/vault.yml.example"
echo ""
echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Review your configuration files:"
echo "   cd $DEPLOYMENT_DIR"
echo "   nano group_vars/all.yml"
echo ""
echo "2. Edit your secrets (vault is encrypted):"
echo "   cd $DEPLOYMENT_DIR"
echo "   ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass"
echo ""
echo "3. Verify vault can be decrypted:"
echo "   cd $DEPLOYMENT_DIR"
echo "   ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | head -5"
echo ""
echo "4. Verify Git ignores your configs:"
echo "   git status"
echo "   # Should show: nothing to commit (or only .example files)"
echo ""
echo "5. Deploy your application:"
echo "   cd $DEPLOYMENT_DIR"
echo "   ./scripts/infra-complete-setup.sh"
echo ""

