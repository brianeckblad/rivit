#!/bin/bash
# Git pre-commit hook to prevent committing secrets
#
# Install this hook:
#   cp deployment/scripts/pre-commit-hook.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit

echo "🔍 Checking for secrets before commit..."

ERRORS=0

# Check for unencrypted vault.yml files
if git diff --cached --name-only | grep -q "vault.yml$"; then
    echo ""
    echo "⚠️  WARNING: vault.yml file detected in commit"

    # Check if it's encrypted
    for file in $(git diff --cached --name-only | grep "vault.yml$"); do
        if [ -f "$file" ]; then
            # Check if file starts with $ANSIBLE_VAULT (encrypted)
            if ! head -n 1 "$file" | grep -q '^\$ANSIBLE_VAULT'; then
                echo "❌ ERROR: Unencrypted vault.yml file: $file"
                echo "   Encrypt it first: ansible-vault encrypt $file"
                ERRORS=$((ERRORS + 1))
            else
                echo "✅ $file is encrypted (safe to commit)"
            fi
        fi
    done
fi

# Check for vault password files
if git diff --cached --name-only | grep -qE "(vault_pass|vault_password|\.vault_pass|\.vault_password)"; then
    echo "❌ ERROR: Vault password file detected!"
    echo "   Files found:"
    git diff --cached --name-only | grep -E "(vault_pass|vault_password|\.vault_pass|\.vault_password)"
    echo "   These should NEVER be committed!"
    ERRORS=$((ERRORS + 1))
fi

# Check for .env files
if git diff --cached --name-only | grep -q "\.env$"; then
    echo "❌ ERROR: .env file detected!"
    echo "   Files found:"
    git diff --cached --name-only | grep "\.env$"
    echo "   Environment files should NEVER be committed!"
    ERRORS=$((ERRORS + 1))
fi

# Check for .local.yml files
if git diff --cached --name-only | grep -q "\.local\.yml$"; then
    echo "❌ ERROR: .local.yml file detected!"
    echo "   Files found:"
    git diff --cached --name-only | grep "\.local\.yml$"
    echo "   Local override files should NEVER be committed!"
    ERRORS=$((ERRORS + 1))
fi

# Check for AWS access keys in diff
if git diff --cached | grep -qE "AKIA[0-9A-Z]{16}"; then
    echo "❌ ERROR: AWS Access Key detected in commit!"
    echo "   Found pattern: AKIA..."
    echo "   AWS credentials should NEVER be committed!"
    ERRORS=$((ERRORS + 1))
fi

# Check for common password patterns
if git diff --cached | grep -qE "(password|passwd|pwd).*=.*['\"][^'\"]{8,}"; then
    echo "⚠️  WARNING: Possible password detected in commit"
    echo "   Review your changes carefully!"
    echo ""
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Commit aborted."
        exit 1
    fi
fi

# Check for private keys
if git diff --cached | grep -q "BEGIN.*PRIVATE KEY"; then
    echo "❌ ERROR: Private key detected in commit!"
    echo "   Private keys should NEVER be committed!"
    ERRORS=$((ERRORS + 1))
fi

# Check for hardcoded domains/IPs that might be personal
if git diff --cached deployment/group_vars/all.yml | grep -qE "(badartink|ipix\.io|rampe)"; then
    echo "⚠️  WARNING: Personal domain/name detected in all.yml"
    echo "   Make sure you're not committing personal configs"
    echo "   Use all.local.yml for personal settings instead"
    echo ""
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Commit aborted."
        exit 1
    fi
fi

echo ""
if [ $ERRORS -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ COMMIT BLOCKED: $ERRORS error(s) found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Fix the errors above before committing."
    echo ""
    exit 1
else
    echo "✅ No secrets detected - commit allowed"
    echo ""
    exit 0
fi

