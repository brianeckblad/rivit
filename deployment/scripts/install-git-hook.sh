#!/bin/bash
# Install the pre-commit hook to prevent committing secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
HOOK_SOURCE="$SCRIPT_DIR/pre-commit-hook.sh"
HOOK_DEST="$PROJECT_ROOT/.git/hooks/pre-commit"

echo "=================================================="
echo "Install Git Pre-Commit Hook"
echo "=================================================="
echo ""
echo "This hook will automatically check for secrets"
echo "before each commit and block commits that contain:"
echo ""
echo "  ❌ Unencrypted vault.yml files"
echo "  ❌ Vault password files"
echo "  ❌ .env files"
echo "  ❌ .local.yml override files"
echo "  ❌ AWS access keys"
echo "  ❌ Private keys"
echo "  ⚠️  Suspicious passwords"
echo ""

# Check if hook already exists
if [ -f "$HOOK_DEST" ]; then
    echo "⚠️  Pre-commit hook already exists."
    echo ""
    read -p "Overwrite existing hook? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    # Backup existing hook
    cp "$HOOK_DEST" "$HOOK_DEST.backup"
    echo "✅ Backed up existing hook to: .git/hooks/pre-commit.backup"
fi

# Install the hook
echo ""
echo "📝 Installing pre-commit hook..."
cp "$HOOK_SOURCE" "$HOOK_DEST"
chmod +x "$HOOK_DEST"

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  Protection Enabled!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The hook will run automatically on every commit."
echo ""
echo "To test it:"
echo "  git commit -m 'test'"
echo ""
echo "To temporarily bypass (NOT RECOMMENDED):"
echo "  git commit --no-verify -m 'message'"
echo ""
echo "To uninstall:"
echo "  rm .git/hooks/pre-commit"
echo ""

