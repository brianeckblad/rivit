#!/bin/bash
#
# Infrastructure Complete Setup
# Supported shells: bash, zsh
# Wrapper script that runs provision-infrastructure.yml playbook
#
# Usage: ./deployment/scripts/infra-complete-setup.sh

set -e

# Shell compatibility check
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
        echo "   Please run with: bash ./deployment/scripts/infra-complete-setup.sh" >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Complete Infrastructure Provisioning                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v ansible-playbook &> /dev/null; then
    echo "ERROR: Ansible not installed. Run: pip install ansible"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not installed."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS CLI not configured. Run: aws configure"
    exit 1
fi

echo "✓ All prerequisites met"
echo ""

# Run the playbook
cd "$DEPLOYMENT_DIR"
echo "Running provision-infrastructure.yml..."
echo ""

ansible-playbook playbooks/provision-infrastructure.yml

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Infrastructure Provisioning Complete!                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Check instance-info.txt for server details"
echo "  2. Update inventories/hosts.yml with IP"
echo "  3. Run: ansible-playbook -i inventories playbooks/setup.yml"
echo ""

