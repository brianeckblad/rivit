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

# Check if vault.yml exists (single source of truth for all configuration)
if [ ! -f "$GROUP_VARS_DIR/vault.yml" ]; then
    echo -e "${RED}❌ Configuration file not found: $GROUP_VARS_DIR/vault.yml${NC}"
    echo ""
    echo "You need to create it from the template. Run:"
    echo "  ./scripts/local-dev-setup.sh"
    echo ""
    echo "This will create vault.yml from vault.yml.example"
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

# all.yml is an empty stub — all config is in vault.yml
# Parse it anyway for backwards compatibility (no-op on an empty file)
if [ -f "$GROUP_VARS_DIR/all.yml" ]; then
    parse_yaml_simple "$GROUP_VARS_DIR/all.yml"
fi

# =========================================================================
# Load SERVER_IP — query AWS or start fresh for a new deployment
# =========================================================================
INVENTORY_FILE="$DEPLOYMENT_DIR/inventories/hosts.yml"


_server_ip=""
_instance_id=""

# ---- Menu: AWS instance or new deployment ----

echo ""
echo "  1) Use an existing AWS instance"
echo "  2) New deployment (no instance yet)"
echo ""
printf "  Select [1-2]: "
read -r _menu_choice

case "$_menu_choice" in

    # ── Option 1: Query AWS for live instances ────────────────────
    1)
        if ! command -v aws &>/dev/null; then
            echo -e "${RED}ERROR: AWS CLI not installed.${NC}"
            return 1 2>/dev/null || exit 1
        fi

        _aws_json=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$app_name" \
                      "Name=instance-state-name,Values=running,stopped,stopping,pending" \
            --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress,Type:InstanceType,Launch:LaunchTime}' \
            --region "$aws_region" --output json 2>/dev/null) || true

        _aws_count=0
        if [ -n "$_aws_json" ] && [ "$_aws_json" != "[]" ]; then
            _aws_count=$(python3 -c "import json; print(len(json.loads('''$_aws_json''')))" 2>/dev/null || echo 0)
        fi

        if [ "$_aws_count" -eq 0 ] 2>/dev/null; then
            echo ""
            echo "No instances found. Re-run and select option 2 for a new deployment."
            return 0 2>/dev/null || exit 0
        elif [ "$_aws_count" -eq 1 ] 2>/dev/null; then
            eval "$(python3 -c "
import json
data = json.loads('''$_aws_json''')
i = data[0]
print(f'_server_ip=\"{i.get(\"IP\") or \"\"}\"')
print(f'_instance_id=\"{i[\"ID\"]}\"')
" 2>/dev/null)"
            if [ -z "$_server_ip" ]; then
                echo -e "${YELLOW}⚠️  Instance ${_instance_id} has no public IP (stopped?)${NC}"
            fi
        else
            echo ""
            echo -e "${YELLOW}Found $_aws_count instances named '$app_name' in AWS:${NC}"
            echo ""
            python3 -c "
import json
data = json.loads('''$_aws_json''')
for idx, i in enumerate(data, 1):
    ip = i.get('IP') or 'no public IP'
    state = i.get('State', '?')
    itype = i.get('Type', '?')
    launched = (i.get('Launch') or '?')[:10]
    print(f'  {idx}) {i[\"ID\"]}   {ip:<16s} {state:<10s} {itype}  launched {launched}')
" 2>/dev/null
            echo ""
            printf "  Select instance [1-%d]: " "$_aws_count"
            read -r _choice

            if [[ "$_choice" =~ ^[0-9]+$ ]] && [ "$_choice" -ge 1 ] && [ "$_choice" -le "$_aws_count" ]; then
                eval "$(python3 -c "
import json
data = json.loads('''$_aws_json''')
i = data[int('$_choice') - 1]
print(f'_server_ip=\"{i.get(\"IP\") or \"\"}\"')
print(f'_instance_id=\"{i[\"ID\"]}\"')
" 2>/dev/null)"
            else
                echo -e "${RED}Invalid selection — SERVER_IP not set${NC}"
            fi
        fi
        ;;

    # ── Option 2: New deployment ──────────────────────────────────
    2)
        # Clear stale instance data from previous runs in this shell
        unset SERVER_IP 2>/dev/null
        unset INSTANCE_ID 2>/dev/null

        echo ""
        echo "Setting up for a new deployment."
        echo ""
        echo "Resetting inventories/hosts.yml to localhost..."

        # Reset hosts.yml to the pre-deploy template (localhost / local)
        if [ -f "$DEPLOYMENT_DIR/inventories/hosts.yml.example" ]; then
            cp "$DEPLOYMENT_DIR/inventories/hosts.yml.example" "$INVENTORY_FILE"
            echo -e "${GREEN}✓ hosts.yml reset to localhost${NC}"
        else
            echo -e "${YELLOW}⚠️  hosts.yml.example not found — hosts.yml not changed${NC}"
        fi
        ;;

    *)
        echo -e "${RED}Invalid choice — SERVER_IP not set${NC}"
        ;;
esac

# ---- Export and sync inventory ----

if [ -n "$_server_ip" ]; then
    export SERVER_IP="$_server_ip"
    [ -n "$_instance_id" ] && export INSTANCE_ID="$_instance_id"

    # Update hosts.yml with the live IP from AWS
    if [ -f "$INVENTORY_FILE" ]; then
        _inv_ip=$(python3 -c "
import re
with open('$INVENTORY_FILE') as f:
    for line in f:
        m = re.search(r'ansible_host:\s*(\S+)', line)
        if m: print(m.group(1)); break
" 2>/dev/null)
        if [ "$_inv_ip" != "$_server_ip" ]; then
            python3 -c "
import re
text = open('$INVENTORY_FILE').read()
text = re.sub(r'(ansible_host:\s*)\S+', r'\g<1>$_server_ip', text)
text = re.sub(r'(ansible_connection:\s*)\S+', r'\g<1>ssh', text)
text = re.sub(r'(# Server IP:\s*)\S+', r'\g<1>$_server_ip', text)
open('$INVENTORY_FILE', 'w').write(text)
" 2>/dev/null
            echo -e "${YELLOW}ℹ️  Updated inventories/hosts.yml: $_inv_ip → $_server_ip${NC}"
        fi
    fi
elif [ -n "$_instance_id" ]; then
    export INSTANCE_ID="$_instance_id"
fi

# ---- Display results ----

echo ""
echo -e "${GREEN}✅ Variables loaded${NC}"
echo ""
echo "  app_name=$app_name"
echo "  app_display_name=${app_display_name:-}"
echo "  aws_region=$aws_region"
echo "  admin_user=${admin_user:-ubuntu}"
echo "  server_name=${server_name:-}"

if [ -n "${SERVER_IP:-}" ]; then
    echo "  SERVER_IP=$SERVER_IP"
    [ -n "${INSTANCE_ID:-}" ] && echo "  INSTANCE_ID=$INSTANCE_ID"
elif [ -n "${INSTANCE_ID:-}" ]; then
    echo "  INSTANCE_ID=$INSTANCE_ID (no public IP — instance may be stopped)"
fi


echo ""

# Show vault status only if there is a problem
if [ "$vault_encrypted" = true ] && [ "$vault_loaded" != true ]; then
    echo -e "${YELLOW}⚠️  vault.yml is encrypted but could not be decrypted${NC}"
    echo "  Create ~/.vault_pass or run: source scripts/load-vars.sh (will prompt)"
elif [ "$vault_encrypted" != true ] && [ -f "$GROUP_VARS_DIR/vault.yml" ]; then
    echo -e "${YELLOW}⚠️  vault.yml is NOT encrypted${NC}"
    echo "  ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass"
fi

