# Local Development & Configuration Management

**How to keep your personal deployment configs out of Git while still pulling updates**

---

## The Problem

You want to:
- ✅ Customize deployment configs for your environment
- ✅ Iterate and develop locally with your settings
- ✅ Pull updates from the main codebase
- ❌ **NEVER** commit your production secrets or personal configs

---

## The Solution: Local Config Override System

We use a **3-tier configuration system**:

```
┌─────────────────────────────────────────────────────┐
│ 1. Template Files (IN GIT)                         │
│    - all.yml (with defaults)                       │
│    - vault.yml.example                             │
│    - These ship generic defaults                   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 2. Local Override Files (IGNORED BY GIT)           │
│    - all.local.yml                                 │
│    - vault.yml                                     │
│    - Your personal settings go here                │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 3. Runtime (Ansible merges them)                   │
│    - Templates + Local = Your deployment           │
└─────────────────────────────────────────────────────┘
```

---

## Setup Instructions

### Option 1: Use Local Override Files (Recommended)

**Best for:** Most users who want simple config management

#### Step 1: Create Your Local Config File

```bash
cd deployment/group_vars

# Copy the template
cp all.yml all.local.yml

# Edit your local settings
nano all.local.yml
```

**Change your values in `all.local.yml`:**
```yaml
app_name: "myapp"
app_display_name: "My Application"
server_name: "myapp.com"
ssl_email: "you@example.com"
```

#### Step 2: Tell Git to Ignore Your Local File

This is already done! The `.gitignore` automatically ignores:
- `all.local.yml`
- `production.local.yml`
- `vault.yml` (when unencrypted)

#### Step 3: Create Your Vault File

```bash
cd deployment/group_vars/production

# Copy the template
cp vault.yml.example vault.yml

# Edit with your secrets
nano vault.yml

# Encrypt it (optional but recommended)
ansible-vault encrypt vault.yml --vault-password-file ~/.vault_pass
```

#### Step 4: Use Your Local Config in Playbooks

Ansible automatically loads files in this order:
1. `all.yml` (base defaults)
2. `all.local.yml` (your overrides) ← **This wins!**
3. `production.yml` (environment-specific)
4. `production.local.yml` (your env overrides)
5. `vault.yml` (secrets)

**No playbook changes needed!** Ansible merges them automatically.

---

### Option 2: Skip Worktree (Advanced)

**Best for:** Users who want to modify the original files directly

This tells Git to **ignore changes** to specific files, even if they're tracked.

#### Mark Files to Never Commit

```bash
cd deployment

# Tell Git to ignore your changes to these files
git update-index --skip-worktree group_vars/all.yml
git update-index --skip-worktree group_vars/production.yml
git update-index --skip-worktree group_vars/production/vault.yml
```

**Now you can edit these files freely and Git will ignore your changes!**

#### Check Which Files Are Skipped

```bash
git ls-files -v | grep ^S
```

Output shows files with `S` (skip-worktree):
```
S deployment/group_vars/all.yml
S deployment/group_vars/production.yml
S deployment/group_vars/production/vault.yml
```

#### Pull Updates From Main Repo

When you pull updates, Git will try to merge. If there's a conflict:

```bash
# Temporarily un-skip to pull updates
git update-index --no-skip-worktree group_vars/all.yml

# Pull the update
git pull

# Review changes and merge manually if needed
nano group_vars/all.yml

# Re-skip the file
git update-index --skip-worktree group_vars/all.yml
```

#### Un-skip Files (if needed)

```bash
# Un-skip a single file
git update-index --no-skip-worktree group_vars/all.yml

# Un-skip all files
git ls-files -v | grep ^S | cut -c3- | xargs git update-index --no-skip-worktree
```

---

### Option 3: Separate Branch (Team Workflow)

**Best for:** Teams with multiple environments

#### Create a Personal/Environment Branch

```bash
# Create a branch for your environment
git checkout -b production-config

# Make your changes
nano group_vars/all.yml
nano group_vars/production/vault.yml
git commit -m "Production config for my environment"

# Keep your branch, never merge to main
git push origin production-config
```

#### Pull Updates From Main

```bash
# Stay on your config branch
git checkout production-config

# Merge updates from main
git fetch origin
git merge origin/main

# Resolve any conflicts
nano group_vars/all.yml
git add .
git commit -m "Merge main updates into production config"
```

**Workflow:**
- `main` branch = Generic template (public)
- `production-config` branch = Your settings (private)
- Pull from `main`, merge conflicts, stay on your branch

---

## Files That Should NEVER Be Committed

### ❌ Never Commit (Already Protected)

```bash
# Vault password files
.vault_pass
.vault_password
vault_pass.txt

# Unencrypted secrets
group_vars/production/vault.yml  # If unencrypted

# Local override files
group_vars/all.local.yml
group_vars/production.local.yml

# Deployment state
.deployment-config
aws-setup-summary.txt
deployment-summary.txt
```

### ✅ Safe to Commit (Encrypted or Generic)

```bash
# Template files (generic defaults)
group_vars/all.yml              # Generic defaults
group_vars/production.yml       # Generic environment settings

# Example files (for documentation)
group_vars/production/vault.yml.example

# Encrypted vault (ONLY if encrypted!)
group_vars/production/vault.yml  # If encrypted with ansible-vault
```

---

## Verification & Safety Checks

### Check What Will Be Committed

**Before every commit:**

```bash
# See what's staged
git status

# See actual changes
git diff --cached

# Make sure no secrets are visible
git diff --cached | grep -E '(password|secret|key|token)'
```

### Pre-Commit Hook (Automatic Protection)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Pre-commit hook to prevent committing secrets

echo "🔍 Checking for secrets..."

# Check for unencrypted vault.yml
if git diff --cached --name-only | grep -q "vault.yml"; then
    if git diff --cached group_vars/production/vault.yml | grep -q "vault_app_password"; then
        echo "❌ ERROR: Attempting to commit unencrypted vault.yml!"
        echo "   Encrypt it first: ansible-vault encrypt vault.yml"
        exit 1
    fi
fi

# Check for vault password files
if git diff --cached --name-only | grep -qE "(vault_pass|\.vault_password)"; then
    echo "❌ ERROR: Attempting to commit vault password file!"
    exit 1
fi

# Check for .env files
if git diff --cached --name-only | grep -q "\.env"; then
    echo "❌ ERROR: Attempting to commit .env file!"
    exit 1
fi

# Check for common secret patterns
if git diff --cached | grep -qE "AKIA[0-9A-Z]{16}"; then
    echo "❌ ERROR: AWS Access Key detected in commit!"
    exit 1
fi

echo "✅ No secrets detected"
exit 0
```

**Install the hook:**

```bash
chmod +x .git/hooks/pre-commit
```

---

## Recommended Workflow

### Initial Setup (Once)

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/your_app.git
cd your_app/deployment

# 2. Create local config files (IGNORED BY GIT)
cp group_vars/all.yml group_vars/all.local.yml
cp group_vars/production/vault.yml.example group_vars/production/vault.yml

# 3. Edit your local configs
nano group_vars/all.local.yml
nano group_vars/production/vault.yml

# 4. Encrypt your vault (optional but recommended)
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-vault encrypt group_vars/production/vault.yml --vault-password-file ~/.vault_pass

# 5. Verify nothing is staged for commit
git status  # Should show "nothing to commit"
```

### Daily Development

```bash
# 1. Pull latest updates from main repo
git pull origin main

# 2. Your local configs are preserved (never committed)
# 3. Make code changes
nano ../app/routes/main.py

# 4. Commit ONLY code changes (configs automatically ignored)
git add ../app/
git commit -m "Add new feature"
git push origin main

# 5. Deploy with YOUR local configs
ansible-playbook -i inventories/production playbooks/update.yml
```

### When Template Files Change

If someone updates `all.yml` with new variables:

```bash
# 1. Pull the update
git pull origin main

# 2. Check what changed
git log -p group_vars/all.yml

# 3. Manually add new variables to your local file
nano group_vars/all.local.yml
# Add any new variables you need

# 4. Your local overrides still take precedence
```

---

## Best Practices

### ✅ DO

1. **Use `.local.yml` files** for all personal configs
2. **Encrypt vault.yml** before committing (if you must commit it)
3. **Use AWS IAM roles** instead of access keys
4. **Use separate branches** for different environments
5. **Always check `git status`** before committing
6. **Use pre-commit hooks** to catch secrets

### ❌ DON'T

1. **Never commit unencrypted secrets**
2. **Never commit vault password files**
3. **Never commit `.env` files**
4. **Never commit AWS access keys**
5. **Never modify templates** if using skip-worktree (use local overrides instead)

---

## Troubleshooting

### "I accidentally committed my secrets!"

```bash
# 1. IMMEDIATELY remove the commit (if not pushed)
git reset HEAD~1

# 2. If already pushed, you MUST rotate all secrets
# - Change all passwords
# - Rotate AWS credentials
# - Generate new tokens

# 3. Remove from Git history (if pushed)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch group_vars/production/vault.yml" \
  --prune-empty --tag-name-filter cat -- --all

git push origin --force --all
```

**Then rotate ALL secrets immediately!**

### "Git wants to commit my local files"

```bash
# Check .gitignore
cat .gitignore | grep vault
cat deployment/.gitignore | grep vault

# Verify files are ignored
git check-ignore -v group_vars/all.local.yml
git check-ignore -v group_vars/production/vault.yml

# If not ignored, add to .gitignore
echo "group_vars/*.local.yml" >> .gitignore
```

### "I can't pull updates, Git says conflict"

```bash
# If using skip-worktree:
git update-index --no-skip-worktree group_vars/all.yml
git stash
git pull
git stash pop
# Resolve conflicts manually
git update-index --skip-worktree group_vars/all.yml

# If using local overrides:
# No conflicts! Your .local.yml files are ignored
git pull  # Works perfectly
```

---

## Summary

**Recommended Approach: Use Local Override Files**

```bash
# Template files (IN GIT)
group_vars/all.yml              # Generic defaults
group_vars/vault.yml.example    # Example secrets

# Your files (IGNORED BY GIT)
group_vars/all.local.yml        # Your settings
group_vars/production/vault.yml # Your secrets
```

**Ansible automatically merges them!** No playbook changes needed.

**Result:**
- ✅ Never commit your secrets
- ✅ Pull updates anytime
- ✅ Keep your settings private
- ✅ Simple workflow

---

## See Also

- [QUICKSTART.md](QUICKSTART.md) - Fast deployment guide
- [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) - Step-by-step deployment
- [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md) - Managing secrets safely

