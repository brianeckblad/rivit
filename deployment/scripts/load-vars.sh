#!/bin/bash
# Load Ansible variables from YAML files for CLI usage
# This script reads group_vars and EXPORTS them as shell variables
#
# Supported shells: bash, zsh
#
# ⚠️  IMPORTANT: You MUST source this script, don't run it directly!
# Usage: source scripts/load-vars.sh
# NOT: ./scripts/load-vars.sh
#
# After sourcing, variables are available:
#   echo $app_name
#   aws s3 ls | grep $app_name

# Shell compatibility check
{
    current_shell=$(ps -p $$ -o comm= 2>/dev/null)
    current_shell=$(basename "$current_shell" 2>/dev/null)
    current_shell=$(echo "$current_shell" | tr -d '-')
    if [[ -z "$current_shell" ]]; then
        current_shell=$(basename "$SHELL" 2>/dev/null)
        current_shell=$(echo "$current_shell" | tr -d '-')
    fi
    case "$current_shell" in
        bash|zsh)
            ;; # Supported shell
        *)
            echo "⚠️  WARNING: Unsupported shell detected!" >&2
            echo "   Current shell: $current_shell" >&2
            echo "   Supported shells: bash, zsh" >&2
            echo "" >&2
            echo "   Please run with: bash -c 'source scripts/load-vars.sh'" >&2
            return 1 2>/dev/null || exit 1
            ;;
    esac
}

# Check if being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "⚠️  ERROR: You must SOURCE this script, don't run it directly!"
    echo ""
    echo "❌ WRONG: ./scripts/load-vars.sh"
    echo "✅ CORRECT: source scripts/load-vars.sh"
    echo ""
    echo "Usage:"
    echo "  cd deployment"
    echo "  source scripts/load-vars.sh"
    echo ""
    echo "Then variables will be available:"
    echo "  echo \$app_name"
    echo "  aws s3 ls | grep \$app_name"
    exit 1
fi

# Script directory and path resolution
# Handle both: sourced from deployment/ and sourced from other locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"

# Verify we're in the right place (DEPLOYMENT_DIR should end with /deployment)
if [[ ! "$DEPLOYMENT_DIR" =~ deployment$ ]]; then
    # If not, we're probably being sourced from deployment directory
    # Try one level up
    if [ -d "group_vars" ]; then
        # group_vars exists in current directory, so current dir IS deployment
        DEPLOYMENT_DIR="$(pwd)"
    else
        # Try assuming we're at deployment level
        DEPLOYMENT_DIR="$(pwd)"
    fi
fi

GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if files exist
if [ ! -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo -e "${RED}❌ Configuration file not found: $GROUP_VARS_DIR/all.yml${NC}"
    echo ""
    echo "You need to create it from the template. Run:"
    echo "  ./scripts/local-dev-setup.sh"
    echo ""
    echo "This will create all.yml from all.yml.example and vault.yml from vault.yml.example"
    echo ""
    return 1 2>/dev/null || exit 1
fi

# Function to safely parse simple YAML key-value pairs
parse_yaml_simple() {
    local file=$1
    local export_count=0
    local line_count=0

    # Read file line by line without subshell (works in bash AND zsh)
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_count=$((line_count+1))

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract lines with key: value format (simple values only)
        if [[ "$line" =~ ^([a-z0-9_]+):[[:space:]]*(.+)$ ]]; then
            # Handle both bash (BASH_REMATCH) and zsh (match) regex arrays
            if [[ -n "${BASH_REMATCH[1]}" ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
            elif [[ -n "${match[1]}" ]]; then
                local key="${match[1]}"
                local value="${match[2]}"
            else
                continue
            fi

            # Skip complex values (Jinja2, lists, dicts)
            if [[ "$value" == *"{{"* ]] || [[ "$value" == *"}}"* ]] || \
               [[ "$value" == "["* ]] || [[ "$value" == "{"* ]]; then
                continue
            fi

            # Remove inline comments
            value="${value%% #*}"

            # Remove quotes (double and single)
            value="${value//\"/}"
            value="${value//\'/}"

            # Simple trim using sed
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Skip empty values
            [[ -z "$value" ]] && continue

            # Export the variable
            export "$key"="$value"
            export_count=$((export_count+1))
        fi
    done < "$file"
}

# Check vault status and load vault variables
vault_encrypted=false
vault_loaded=false
if [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    if head -1 "$GROUP_VARS_DIR/vault.yml" 2>/dev/null | grep -q "ANSIBLE_VAULT"; then
        vault_encrypted=true
        # Decrypt vault to load variables
        vault_content=""
        if [ -f "$HOME/.vault_pass" ]; then
            vault_content=$(ansible-vault view "$GROUP_VARS_DIR/vault.yml" \
                --vault-password-file "$HOME/.vault_pass" 2>/dev/null)
        else
            echo -e "${YELLOW}ℹ️  ~/.vault_pass not found — enter vault password to load secrets${NC}"
            vault_content=$(ansible-vault view "$GROUP_VARS_DIR/vault.yml" \
                --ask-vault-pass 2>/dev/null)
        fi
        if [ -n "$vault_content" ]; then
            # Parse decrypted content line by line (same logic as parse_yaml_simple)
            while IFS= read -r line || [[ -n "$line" ]]; do
                [[ -z "$line" ]] && continue
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                if [[ "$line" =~ ^([a-z0-9_]+):[[:space:]]*(.+)$ ]]; then
                    if [[ -n "${BASH_REMATCH[1]}" ]]; then
                        key="${BASH_REMATCH[1]}"
                        value="${BASH_REMATCH[2]}"
                    elif [[ -n "${match[1]}" ]]; then
                        key="${match[1]}"
                        value="${match[2]}"
                    else
                        continue
                    fi
                    [[ "$value" == *"{{"* ]] && continue
                    value="${value%% #*}"
                    value="${value//\"/}"
                    value="${value//\'/}"
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    # Export even empty values (overrides inherited env vars)
                    export "$key"="$value"
                fi
            done <<< "$vault_content"
            vault_loaded=true
        else
            echo -e "${RED}⚠️  Could not decrypt vault.yml — vault variables not loaded${NC}"
        fi
    else
        # Load vault variables if not encrypted
        parse_yaml_simple "$GROUP_VARS_DIR/vault.yml"
        vault_loaded=true
    fi
fi

# Load all.yml variables (plain values)
parse_yaml_simple "$GROUP_VARS_DIR/all.yml"

# Load SERVER_IP — try instance-info.txt first, fall back to inventories/hosts.yml
INSTANCE_INFO="$DEPLOYMENT_DIR/instance-info.txt"
INVENTORY_FILE="$DEPLOYMENT_DIR/inventories/hosts.yml"

_server_ip=""

# Primary source: instance-info.txt (written by launch-ec2-instance.yml)
if [ -f "$INSTANCE_INFO" ]; then
    _server_ip=$(python3 -c "
import re
with open('$INSTANCE_INFO') as f:
    for line in f:
        m = re.search(r'Public IP Address:\s+(\S+)', line)
        if m:
            print(m.group(1))
            break
" 2>/dev/null)
fi

# Fallback: read from inventories/hosts.yml if instance-info.txt missing or empty
if [ -z "$_server_ip" ] && [ -f "$INVENTORY_FILE" ]; then
    _server_ip=$(python3 -c "
import re
with open('$INVENTORY_FILE') as f:
    for line in f:
        m = re.search(r'ansible_host:\s*(\S+)', line)
        if m:
            ip = m.group(1)
            # Skip placeholder values (not a real IP)
            if re.match(r'\d+\.\d+\.\d+\.\d+', ip):
                print(ip)
            break
" 2>/dev/null)
fi

if [ -n "$_server_ip" ]; then
    export SERVER_IP="$_server_ip"

    # Keep inventory in sync — update ansible_host if it differs
    if [ -f "$INVENTORY_FILE" ]; then
        _inv_ip=$(python3 -c "
import re
with open('$INVENTORY_FILE') as f:
    for line in f:
        m = re.search(r'ansible_host:\s*(\S+)', line)
        if m:
            print(m.group(1))
            break
" 2>/dev/null)
        if [ "$_inv_ip" != "$_server_ip" ]; then
            # Update the IP in hosts.yml and the comment header
            python3 -c "
import re
text = open('$INVENTORY_FILE').read()
text = re.sub(r'(ansible_host:\s*)\S+', r'\g<1>$_server_ip', text)
text = re.sub(r'(# Server IP:\s*)\S+', r'\g<1>$_server_ip', text)
open('$INVENTORY_FILE', 'w').write(text)
" 2>/dev/null
            echo -e "${YELLOW}ℹ️  Updated inventories/hosts.yml: $_inv_ip → $_server_ip${NC}"
        fi
    fi
fi

# Resolve Jinja2 references: {{ var | default('val') }}
# Uses Python for reliable regex parsing (avoids zsh regex/typeset issues)
# Handles lines like: aws_region: "{{ vault_aws_region | default('us-east-2') }}"
eval "$(python3 -c "
import re, os
with open('$GROUP_VARS_DIR/all.yml') as f:
    for line in f:
        m = re.match(r'^([a-z0-9_]+):\s*\"?\{\{\s*([a-z0-9_]+)\s*\|\s*default\([\\x27\"](.*?)[\\x27\"]\)\s*\}\}\"?', line)
        if m:
            key, src, fallback = m.groups()
            value = os.environ.get(src, fallback)
            # Escape double quotes and backslashes in value
            value = value.replace(chr(92), chr(92)*2).replace('\"', '\\\\\"')
            print(f'export {key}=\"{value}\"')
" 2>/dev/null)"

# Display status and available variables
echo -e "${GREEN}✅ Variables loaded and EXPORTED successfully${NC}"
echo ""
echo "Available variables (exported to this shell):"
echo "  app_name=$app_name"
echo "  app_display_name=$app_display_name"
echo "  aws_region=$aws_region"
echo "  admin_user=$admin_user"
echo "  server_name=$server_name"
if [ -n "$SERVER_IP" ]; then
    echo "  SERVER_IP=$SERVER_IP"
else
    echo "  SERVER_IP=(not set — launch an instance first)"
fi
echo ""
echo "Variables are NOW AVAILABLE in your shell."
echo ""
echo "You can use them in scripts and with deployment playbooks:"
echo "  - Configuration: app_name=$app_name, aws_region=$aws_region, etc."
echo "  - In scripts: \$app_name, \$aws_region, \$admin_user, etc."
echo "  - In playbooks: variables passed to ansible-playbook"
echo ""
echo "AWS resources (S3, IAM roles, security groups) don't exist yet."
echo "They will be created when you run the deployment playbooks."
echo ""
echo "List all exported variables:"
echo "  env | grep -E '^(app_|aws_|admin_|SERVER_)' | sort"
echo ""

# Show vault status
if [ "$vault_encrypted" = true ]; then
    if [ "$vault_loaded" = true ]; then
        echo -e "${GREEN}🔓 vault.yml decrypted and loaded${NC}"
    else
        echo -e "${YELLOW}⚠️  vault.yml is encrypted but could not be decrypted${NC}"
        echo "Variables from vault.yml (aws_region, etc.) are not available."
        echo ""
        echo "To fix:"
        echo "  1. Create ~/.vault_pass with your vault password"
        echo "  2. Or run: source scripts/load-vars.sh (will prompt for password)"
    fi
else
    echo -e "${YELLOW}⚠️  Warning: vault.yml is NOT encrypted!${NC}"
    echo "Your secrets are visible in plain text. Encrypt it with:"
    echo "  ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass"
fi

