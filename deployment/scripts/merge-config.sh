#!/bin/bash
# Merge configuration from existing files into new templates
# Useful when updating templates - preserves existing values
#
# Usage:
#   ./scripts/merge-config.sh              # Interactive merge
#   ./scripts/merge-config.sh --no-backup  # Skip backup creation
#   ./scripts/merge-config.sh --force      # Overwrite without confirmation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
NO_BACKUP=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-backup] [--force]"
            exit 1
            ;;
    esac
done

echo "=================================================="
echo "Configuration Merge Tool"
echo "=================================================="
echo ""
echo "This tool merges existing configuration into new templates."
echo "Useful when updating templates - preserves your existing values."
echo ""

# Check if templates exist
if [ ! -f "$GROUP_VARS_DIR/all.yml.example" ]; then
    echo "❌ Error: all.yml.example not found"
    exit 1
fi

if [ ! -f "$GROUP_VARS_DIR/vault.yml.example" ]; then
    echo "❌ Error: vault.yml.example not found"
    exit 1
fi

# Function to extract value from YAML file
extract_yaml_value() {
    local file="$1"
    local key="$2"

    # Look for key followed by : and capture the value
    # Handles: key: value, key: "value", key: 'value'
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//; s/['\"]//g; s/#.*//" | sed 's/[[:space:]]*$//' | head -1
}

# Function to extract variables from YAML file that reference vault
extract_vault_variables() {
    local file="$1"

    # Find all lines that reference vault_ variables
    grep -E "vault_[a-z_]+:" "$file" 2>/dev/null | sed "s/.*\(vault_[a-z_]*\):.*/\1/" | sort -u
}

echo "📋 Checking for existing configuration files..."
echo ""

HAS_ALL_YML=false
HAS_VAULT_YML=false

if [ -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo "✅ Found: all.yml (will merge values)"
    HAS_ALL_YML=true
else
    echo "⊘  Not found: all.yml (will use template)"
fi

if [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    echo "✅ Found: vault.yml (will merge values)"
    HAS_VAULT_YML=true
else
    echo "⊘  Not found: vault.yml (will use template)"
fi

echo ""

if [ "$HAS_ALL_YML" = false ] && [ "$HAS_VAULT_YML" = false ]; then
    echo "ℹ️  No existing files found. Creating new configuration files..."
    echo ""
    cp "$GROUP_VARS_DIR/all.yml.example" "$GROUP_VARS_DIR/all.yml"
    echo "✅ Created: all.yml"

    cp "$GROUP_VARS_DIR/vault.yml.example" "$GROUP_VARS_DIR/vault.yml"
    echo "✅ Created: vault.yml (unencrypted, ready to edit)"

    echo ""
    echo "=================================================="
    echo "✅ New configuration files created!"
    echo "=================================================="
    echo ""
    echo "Next steps:"
    echo "  1. Edit your configuration files:"
    echo "     nano group_vars/all.yml"
    echo "     nano group_vars/vault.yml"
    echo ""
    echo "  2. Configure git:"
    echo "     ./scripts/configure-git.sh"
    echo ""
    echo "  3. Ready to deploy!"
    exit 0
fi

# Create backups if files exist
if [ "$NO_BACKUP" = false ]; then
    echo "📦 Creating backups..."

    if [ "$HAS_ALL_YML" = true ]; then
        BACKUP_FILE="$GROUP_VARS_DIR/all.yml.backup.$(date +%s)"
        cp "$GROUP_VARS_DIR/all.yml" "$BACKUP_FILE"
        echo "  ✅ Backed up: all.yml → $(basename "$BACKUP_FILE")"
    fi

    if [ "$HAS_VAULT_YML" = true ]; then
        # Decrypt vault if encrypted
        if head -1 "$GROUP_VARS_DIR/vault.yml" | grep -q "ANSIBLE_VAULT"; then
            echo "  🔓 Decrypting vault.yml..."
            VAULT_PASS_FILE="$HOME/.vault_pass"

            if [ ! -f "$VAULT_PASS_FILE" ]; then
                # File doesn't exist - prompt for password
                echo "     Vault password file not found. Please enter your vault password:"
                read -s -p "     Vault password: " VAULT_PASSWORD < /dev/tty
                echo ""
                # Create temp file with password for ansible-vault
                TEMP_PASS=$(mktemp)
                echo "$VAULT_PASSWORD" > "$TEMP_PASS"
                VAULT_PASS_FILE="$TEMP_PASS"
                TEMP_PASS_CREATED=true
            fi

            DECRYPTED_BACKUP="$GROUP_VARS_DIR/vault.yml.decrypted.$(date +%s)"
            ansible-vault decrypt "$GROUP_VARS_DIR/vault.yml" --vault-password-file "$VAULT_PASS_FILE" --output "$DECRYPTED_BACKUP" 2>/dev/null
            BACKUP_FILE="$DECRYPTED_BACKUP"

            # Clean up temp password file if we created one
            if [ "$TEMP_PASS_CREATED" = true ]; then
                rm -f "$TEMP_PASS"
            fi
        else
            BACKUP_FILE="$GROUP_VARS_DIR/vault.yml.backup.$(date +%s)"
            cp "$GROUP_VARS_DIR/vault.yml" "$BACKUP_FILE"
        fi
        echo "  ✅ Backed up: vault.yml → $(basename "$BACKUP_FILE")"
    fi

    echo ""
fi

# Merge all.yml
if [ "$HAS_ALL_YML" = true ]; then
    echo "🔄 Merging all.yml..."

    # Copy template
    cp "$GROUP_VARS_DIR/all.yml.example" "$GROUP_VARS_DIR/all.yml.merged"

    # Extract all key-value pairs from existing all.yml
    # Find lines that look like: key: value (not starting with # or blank)
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Extract key and value
        if [[ "$line" =~ ^([a-z_]+): ]]; then
            KEY="${BASH_REMATCH[1]}"
            VALUE=$(echo "$line" | sed "s/^${KEY}:[[:space:]]*//; s/#.*//" | sed 's/[[:space:]]*$//')

            # Replace value in merged file (only the simple key: value lines, not templated ones)
            # Only replace if it's not a computed/auto-configured value
            if ! grep -q "^${KEY}:[[:space:]]*{{" "$GROUP_VARS_DIR/all.yml.example"; then
                # Escape special characters for sed
                VALUE_ESCAPED=$(printf '%s\n' "$VALUE" | sed -e 's/[\/&]/\\&/g')
                sed -i.tmp "s|^${KEY}:.*|${KEY}: ${VALUE_ESCAPED}|" "$GROUP_VARS_DIR/all.yml.merged" && rm -f "$GROUP_VARS_DIR/all.yml.merged.tmp"
            fi
        fi
    done < "$GROUP_VARS_DIR/all.yml"

    mv "$GROUP_VARS_DIR/all.yml.merged" "$GROUP_VARS_DIR/all.yml"
    echo "  ✅ Merged existing values into all.yml"
else
    cp "$GROUP_VARS_DIR/all.yml.example" "$GROUP_VARS_DIR/all.yml"
    echo "  ✅ Created all.yml from template"
fi

# Merge vault.yml
if [ "$HAS_VAULT_YML" = true ]; then
    echo "🔄 Merging vault.yml..."

    # If vault is encrypted, decrypt it first
    OLD_VAULT_FILE="$GROUP_VARS_DIR/vault.yml"
    if head -1 "$OLD_VAULT_FILE" | grep -q "ANSIBLE_VAULT"; then
        echo "  🔓 Decrypting existing vault.yml..."
        VAULT_PASS_FILE="$HOME/.vault_pass"
        if [ ! -f "$VAULT_PASS_FILE" ]; then
            echo "❌ Error: Vault password file not found at $VAULT_PASS_FILE"
            exit 1
        fi

        # Create temp decrypted file
        TEMP_VAULT=$(mktemp)
        ansible-vault decrypt "$OLD_VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" --output "$TEMP_VAULT" 2>/dev/null
        OLD_VAULT_FILE="$TEMP_VAULT"
    fi

    # Copy template
    cp "$GROUP_VARS_DIR/vault.yml.example" "$GROUP_VARS_DIR/vault.yml.merged"

    # Extract vault variables from existing file
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Extract key and value (vault variables)
        if [[ "$line" =~ ^([a-z_]+): ]]; then
            KEY="${BASH_REMATCH[1]}"
            VALUE=$(echo "$line" | sed "s/^${KEY}:[[:space:]]*//; s/#.*//" | sed 's/[[:space:]]*$//')

            # Replace in merged file
            VALUE_ESCAPED=$(printf '%s\n' "$VALUE" | sed -e 's/[\/&]/\\&/g')
            sed -i.tmp "s|^${KEY}:.*|${KEY}: ${VALUE_ESCAPED}|" "$GROUP_VARS_DIR/vault.yml.merged" && rm -f "$GROUP_VARS_DIR/vault.yml.merged.tmp"
        fi
    done < "$OLD_VAULT_FILE"

    # Clean up temp file if we created one
    if [ -n "$TEMP_VAULT" ] && [ -f "$TEMP_VAULT" ]; then
        rm -f "$TEMP_VAULT"
    fi

    mv "$GROUP_VARS_DIR/vault.yml.merged" "$GROUP_VARS_DIR/vault.yml"
    echo "  ✅ Merged existing values into vault.yml"
    echo "  ✅ Vault is unencrypted (ready to edit)"
else
    cp "$GROUP_VARS_DIR/vault.yml.example" "$GROUP_VARS_DIR/vault.yml"
    echo "  ✅ Created vault.yml from template (unencrypted)"
fi

echo ""
echo "=================================================="
echo "✅ Configuration Merge Complete!"
echo "=================================================="
echo ""
echo "Your existing values have been merged into the new templates."
echo "Only NEW values (from template updates) need to be configured."
echo ""
echo "Next steps:"
echo "  1. Review the merged files:"
echo "     nano group_vars/all.yml"
echo "     nano group_vars/vault.yml"
echo ""
echo "  2. Add any NEW configuration values from the templates"
echo "     (Look for comments marked as NEW or changed)"
echo ""
echo "  3. When ready, encrypt the vault:"
echo "     ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default"
echo ""
echo "  4. Configure git (if needed):"
echo "     ./scripts/configure-git.sh"
echo ""
echo "  5. Deploy:"
echo "     ./scripts/infra-complete-setup.sh"
echo ""

