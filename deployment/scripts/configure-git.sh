#!/bin/bash
# Configure git user email based on deployment configuration
# This script extracts the email from your deployment config and sets it in git

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"
GROUP_VARS_DIR="$DEPLOYMENT_DIR/group_vars"

echo "=================================================="
echo "Git Configuration Setup"
echo "=================================================="
echo ""

# Check if all.yml exists
if [ ! -f "$GROUP_VARS_DIR/all.yml" ]; then
    echo "❌ Error: group_vars/all.yml not found"
    echo "   Run ./scripts/local-dev-setup.sh first"
    exit 1
fi

# Extract values from all.yml
APP_NAME=$(grep "^app_name:" "$GROUP_VARS_DIR/all.yml" | awk '{print $2}' | tr -d '"')
SSL_EMAIL=$(grep "^ssl_email:" "$GROUP_VARS_DIR/all.yml" | awk '{print $2}' | tr -d '"')
SERVER_NAME=$(grep "^server_name:" "$GROUP_VARS_DIR/all.yml" | awk '{print $2}' | tr -d '"')

if [ -z "$APP_NAME" ] || [ -z "$SSL_EMAIL" ]; then
    echo "❌ Error: Could not read configuration from group_vars/all.yml"
    echo "   Make sure app_name and ssl_email are set"
    exit 1
fi

echo "📝 Configuration detected:"
echo "   App name: $APP_NAME"
echo "   Email: $SSL_EMAIL"
echo "   Domain: $SERVER_NAME"
echo ""

# Ask user for scope
echo "Configure git for:"
echo "  1. This repository only (local)"
echo "  2. All repositories (global)"
echo ""
read -p "Choose 1 or 2 [default: 1]: " -r SCOPE
SCOPE=${SCOPE:-1}

if [ "$SCOPE" = "2" ]; then
    # Global configuration
    echo ""
    echo "Setting git config globally..."
    echo "   user.email: $SSL_EMAIL"
    git config --global user.email "$SSL_EMAIL"

    # Also set name if not set
    if ! git config --global user.name > /dev/null 2>&1; then
        read -p "Git user name (for global config) [default: $APP_NAME]: " -r GIT_NAME
        GIT_NAME=${GIT_NAME:-$APP_NAME}
        git config --global user.name "$GIT_NAME"
        echo "   user.name: $GIT_NAME"
    fi

    echo ""
    echo "✅ Global git config set"
    echo ""
    echo "View your settings:"
    echo "   git config --global user.name"
    echo "   git config --global user.email"
else
    # Local (per-repository) configuration
    # Must be run from repository root
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

    if [ -z "$REPO_ROOT" ]; then
        echo "❌ Error: Not in a git repository"
        echo "   Change to repository root and try again"
        exit 1
    fi

    echo ""
    echo "Setting git config for this repository..."
    echo "   Email: $SSL_EMAIL"

    cd "$REPO_ROOT"
    git config user.email "$SSL_EMAIL"

    # Also set name if not set locally
    if ! git config user.name > /dev/null 2>&1; then
        read -p "Git user name for this repo [default: $APP_NAME]: " -r GIT_NAME
        GIT_NAME=${GIT_NAME:-$APP_NAME}
        git config user.name "$GIT_NAME"
        echo "   Name: $GIT_NAME"
    fi

    echo ""
    echo "✅ Local git config set (.git/config)"
    echo ""
    echo "View your settings:"
    echo "   git config user.name"
    echo "   git config user.email"
fi

echo ""
echo "=================================================="
echo "✅ Git configuration complete!"
echo "=================================================="
echo ""
echo "Your commits will now use:"
echo "   Author: $(git config user.name) <$(git config user.email)>"
echo ""
echo "To change later:"
echo "   git config user.email \"newaddress@domain.com\""
echo ""

