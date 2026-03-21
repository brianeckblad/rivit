#!/bin/bash
#
# Decommission - Resource Discovery and Teardown
# Supported shells: bash, zsh
#
# Interactive wrapper that checks for existing resources before
# calling the decommission playbook.  Provides graceful exits
# when there is nothing to tear down.
#
# Usage:
#   cd deployment
#   ./scripts/decommission.sh
#
# What it does:
#   1. Presents a discovery menu (AWS / local files / new deployment)
#   2. Checks whether resources actually exist
#   3. Only calls the playbook when there is something to remove

set -e

# ── Shell compatibility ──────────────────────────────────────────────
current_shell=$(ps -p $$ -o comm= 2>/dev/null)
current_shell=$(basename "$current_shell" 2>/dev/null)
current_shell=$(echo "$current_shell" | tr -d '-')
if [[ -z "$current_shell" ]]; then
    current_shell=$(basename "$SHELL" 2>/dev/null)
    current_shell=$(echo "$current_shell" | tr -d '-')
fi
case "$current_shell" in
    bash|zsh) ;;
    *)
        echo "⚠️  Unsupported shell: $current_shell (need bash or zsh)" >&2
        exit 1
        ;;
esac

# ── Resolve paths ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"

# ── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Load app_name and aws_region ─────────────────────────────────────
if [[ ! -f "$GROUP_VARS_DIR/vault.yml" ]]; then
    echo -e "${RED}ERROR: $GROUP_VARS_DIR/vault.yml not found${NC}"
    echo "Run ./scripts/local-dev-setup.sh first."
    exit 1
fi

# Read app_name from vault (handles encrypted and unencrypted)
app_name=""
if head -1 "$GROUP_VARS_DIR/vault.yml" 2>/dev/null | grep -q "ANSIBLE_VAULT"; then
    if [[ -f "$HOME/.vault_pass" ]]; then
        app_name=$(ansible-vault view "$GROUP_VARS_DIR/vault.yml" \
            --vault-password-file "$HOME/.vault_pass" 2>/dev/null \
            | grep -E "^app_name:" | head -1 \
            | sed 's/^app_name:[[:space:]]*//' | sed 's/#.*//' \
            | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
    fi
else
    app_name=$(grep -E "^app_name:" "$GROUP_VARS_DIR/vault.yml" | head -1 \
        | sed 's/^app_name:[[:space:]]*//' | sed 's/#.*//' \
        | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
fi

if [[ -z "$app_name" ]]; then
    echo -e "${RED}ERROR: app_name not set in vault.yml${NC}"
    exit 1
fi

# Resolve aws_region — try vault first, then default
aws_region=""
if [[ -f "$HOME/.vault_pass" ]] && [[ -f "$GROUP_VARS_DIR/vault.yml" ]]; then
    aws_region=$(ansible-vault view "$GROUP_VARS_DIR/vault.yml" \
        --vault-password-file "$HOME/.vault_pass" 2>/dev/null \
        | grep -E "^aws_region:" | head -1 \
        | sed 's/^aws_region:[[:space:]]*//' | sed 's/#.*//' \
        | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
fi
if [[ -z "$aws_region" ]]; then
    aws_region="us-east-2"
fi


# ── Discovery menu ───────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            Decommission — Resource Discovery             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  App:    $app_name"
echo "  Region: $aws_region"
echo ""
echo "    1) Query AWS for live instance data"
echo "    2) This is a new deployment (nothing to decommission)"
echo ""
printf "  Enter choice [1-2]: "
read -r menu_choice

case "$menu_choice" in

    # ── Option 1: Query AWS ──────────────────────────────────────
    1)
        echo ""
        echo "Querying AWS for EC2 instances named '$app_name' in $aws_region..."

        if ! command -v aws &>/dev/null; then
            echo -e "${RED}ERROR: AWS CLI not installed.${NC}"
            exit 1
        fi

        aws_json=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$app_name" \
                      "Name=instance-state-name,Values=running,stopped,stopping,pending" \
            --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress,Type:InstanceType}' \
            --region "$aws_region" --output json 2>/dev/null) || true

        aws_count=0
        if [[ -n "$aws_json" && "$aws_json" != "[]" ]]; then
            aws_count=$(python3 -c "import json; print(len(json.loads('''$aws_json''')))" 2>/dev/null || echo 0)
        fi

        if [[ "$aws_count" -eq 0 ]]; then
            echo ""
            echo "  No running or stopped instances named '$app_name' in $aws_region."
            echo ""
            exit 0
        fi

        echo ""
        echo -e "${GREEN}Found $aws_count instance(s) in AWS:${NC}"
        echo ""
        python3 -c "
import json
data = json.loads('''$aws_json''')
for i in data:
    ip = i.get('IP') or 'no public IP'
    print(f'  {i[\"ID\"]}  {i[\"State\"]:<10s}  {ip:<16s}  {i[\"Type\"]}')
" 2>/dev/null
        echo ""
        echo "These resources will be targeted for decommission."
        ;;

    # ── Option 2: New deployment ─────────────────────────────────
    2)
        echo ""
        echo "  Nothing to decommission."
        echo ""
        exit 0
        ;;

    # ── Invalid ──────────────────────────────────────────────────
    *)
        echo -e "${RED}Invalid choice. Run again and enter 1 or 2.${NC}"
        exit 1
        ;;
esac

# ── Confirm before calling the playbook ──────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ⚠️  DESTRUCTIVE OPERATION — ALL DATA WILL BE DELETED   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  This will permanently delete ALL resources for '$app_name'."
echo ""
printf "  Type the app name to confirm: "
read -r confirm

if [[ "$confirm" != "$app_name" ]]; then
    echo ""
    echo -e "${RED}Confirmation failed.${NC} You typed '$confirm' but app_name is '$app_name'."
    echo "Run again and type '$app_name' to confirm."
    exit 1
fi

echo ""
echo "Starting decommission..."
echo ""

# ── Run the playbook ─────────────────────────────────────────────────
cd "$DEPLOYMENT_DIR"
ansible-playbook playbooks/decommission.yml \
    --vault-password-file ~/.vault_pass \
    -e "decommission_confirmed=true"

