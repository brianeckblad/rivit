#!/bin/bash
#
# Remote Deployment Script
#
# This script simplifies remote deployment from your local machine
# It handles the most common deployment scenarios
#
# Usage:
#   ./deployment/scripts/app-deploy.sh setup     # Initial setup
#   ./deployment/scripts/app-deploy.sh update     # Update after git push
#   ./deployment/scripts/app-deploy.sh hardening # Security hardening
#   ./deployment/scripts/app-deploy.sh cleanup    # Clean server files
#   ./deployment/scripts/app-deploy.sh logs       # View recent logs
#   ./deployment/scripts/app-deploy.sh status     # Check status

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the app name getter function
source "$SCRIPT_DIR/lib/get_app_name.sh"

# Get app name from config (or use environment variable override)
if [ -z "$APP_NAME" ]; then
    APP_NAME=$(get_app_name) || exit 1
fi

echo "Using app_name: $APP_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${DEPLOYMENT_DIR}/inventories/hosts.yml"
VAULT_FILE="${DEPLOYMENT_DIR}/group_vars/vault.yml"

# Functions
usage() {
    cat << EOF
${BLUE}Remote Deployment Helper${NC}

Usage: $0 <command> [options]

Commands:
  setup           Run initial server setup (one-time)
  update          Update server after git push (most common)
  hardening       Apply security hardening
  cleanup         Remove deployment files from server
  logs            View recent application logs
  status          Check application status
  rollback        Rollback to previous version (needs commit hash)

Examples:
  $0 setup                           # Initial setup
  $0 update                          # After git push
  $0 hardening                       # Security hardening
  $0 logs                            # View logs
  $0 status                          # Check status
  $0 rollback abc1234                # Rollback to commit abc1234

For more info, see: deployment/docs/guides/MANUAL_DEPLOYMENT.md

${YELLOW}WARNING:${NC} Make sure you have:
  1. Vault password (optional - will prompt if ~/.vault_pass missing): echo 'password' > ~/.vault_pass && chmod 600 ~/.vault_pass
  2. Hosts configured: deployment/inventories/hosts.yml
  3. Code pushed to GitHub: git push origin main

EOF
    exit 1
}

print_section() {
    echo ""
    echo -e "${BLUE}▶${NC} $1"
    echo ""
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking prerequisites..."

    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible not installed. Run: pip install ansible"
    fi
    success "Ansible found"

    if [[ ! -f "$INVENTORY" ]]; then
        error "Inventory file not found: $INVENTORY"
    fi
    success "Inventory file found"

    if [[ ! -f "$VAULT_FILE" ]]; then
        warning "Vault file not found. Create it with:"
        warning "  ansible-vault create deployment/group_vars/vault.yml"
    else
        success "Vault file found"
    fi

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository. Change to project root."
    fi
    success "In git repository"
}

# Setup command
cmd_setup() {
    print_section "Running initial server setup..."
    warning "This should only be run once on a new server"
    echo ""
    read -p "Continue with setup? (type 'yes' to confirm): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    check_prerequisites

    print_section "Running setup playbook..."
    ansible-playbook -i "$INVENTORY" \
        "${DEPLOYMENT_DIR}/playbooks/setup.yml" \
        --ask-vault-pass \
        -v

    success "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Run security hardening: $0 hardening"
    echo "  2. Verify application: ssh ubuntu@your-server-ip"
    echo "  3. Check logs: $0 logs"
}

# Update command
cmd_update() {
    print_section "Deploying update to server..."

    check_prerequisites

    # Verify code is pushed
    if git status --porcelain | grep -q .; then
        warning "You have uncommitted changes. Commit them first:"
        echo "  git add ."
        echo "  git commit -m 'Your message'"
        echo "  git push origin main"
        exit 1
    fi

    if [[ $(git rev-parse HEAD) != $(git ls-remote origin main | awk '{print $1}') ]]; then
        warning "Your code is not pushed to GitHub. Run:"
        echo "  git push origin main"
        exit 1
    fi

    print_section "Running remote update playbook..."
    ansible-playbook -i "$INVENTORY" \
        "${DEPLOYMENT_DIR}/playbooks/remote-update.yml" \
        --ask-vault-pass \
        -v

    success "Update complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify application: $0 status"
    echo "  2. Check logs: $0 logs"
    echo "  3. Run health checks on your application"
}

# Hardening command
cmd_hardening() {
    print_section "Running security hardening..."

    check_prerequisites

    ansible-playbook -i "$INVENTORY" \
        "${DEPLOYMENT_DIR}/playbooks/security-hardening.yml" \
        --ask-vault-pass \
        -v

    success "Security hardening complete!"
}

# Cleanup command
cmd_cleanup() {
    print_section "Cleaning up server..."
    warning "This removes deployment files, docs, and .git from server"
    echo ""
    read -p "Continue with cleanup? (type 'yes' to confirm): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi

    check_prerequisites

    ansible-playbook -i "$INVENTORY" \
        "${DEPLOYMENT_DIR}/playbooks/cleanup-server.yml" \
        --ask-vault-pass \
        -v

    success "Cleanup complete!"
    echo ""
    echo "Server now contains only essential application files."
}

# Logs command
cmd_logs() {
    print_section "Fetching recent logs from server..."

    check_prerequisites

    ansible -i "$INVENTORY" all \
        -m shell \
        -a "tail -30 /var/log/app_item_listing_tool/app.log 2>/dev/null || echo 'No logs yet'" \
        -u ubuntu

    echo ""
    echo "For live logs, SSH to server and run:"
    echo "  journalctl -u app_item_listing_tool -f"
}

# Status command
cmd_status() {
    print_section "Checking application status..."

    check_prerequisites

    ansible -i "$INVENTORY" all \
        -m systemd \
        -a "name=app_item_listing_tool state=started" \
        -u ubuntu --become

    echo ""
    echo "To SSH and check manually:"
    echo "  ssh ubuntu@your-server-ip"
    echo "  systemctl status app_item_listing_tool"
}

# Rollback command
cmd_rollback() {
    if [[ -z "$1" ]]; then
        error "Rollback requires a commit hash. Usage: $0 rollback <commit-hash>"
    fi

    COMMIT_HASH="$1"
    print_section "Rolling back to commit: $COMMIT_HASH"
    warning "This will change the application to a specific commit"
    echo ""
    read -p "Continue with rollback? (type 'yes' to confirm): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Rollback cancelled."
        exit 0
    fi

    check_prerequisites

    # SSH to server and rollback
    echo "Connecting to server to perform rollback..."
    ansible -i "$INVENTORY" all \
        -m shell \
        -a "cd /home/ubuntu/${APP_NAME} && git checkout $COMMIT_HASH" \
        -u ubuntu --become

    # Restart service
    ansible -i "$INVENTORY" all \
        -m systemd \
        -a "name=${APP_NAME} state=restarted" \
        -u ubuntu --become

    success "Rollback complete! Server is now at commit: $COMMIT_HASH"
    echo ""
    echo "Verify with: $0 status"
}

# Main
if [[ $# -eq 0 ]]; then
    usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
    setup)
        cmd_setup
        ;;
    update)
        cmd_update
        ;;
    hardening)
        cmd_hardening
        ;;
    cleanup)
        cmd_cleanup
        ;;
    logs)
        cmd_logs
        ;;
    status)
        cmd_status
        ;;
    rollback)
        cmd_rollback "$@"
        ;;
    *)
        usage
        ;;
esac
