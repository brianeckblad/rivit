# Configuration Setup Guide

**Use `local-dev-setup.sh` for both new setup and merging configurations**

---

## Overview

The `local-dev-setup.sh` script handles both:
- **New setup** - Create fresh configuration from templates
- **Merging** - Preserve existing values when templates are updated

This replaces the need for separate scripts.

---

## Quick Start

```bash
cd deployment

# Auto-detect and choose
./scripts/local-dev-setup.sh

# OR explicitly:

# Fresh setup
./scripts/local-dev-setup.sh -new

# Merge existing with updated templates
./scripts/local-dev-setup.sh -merge
```

---

## Usage Modes

### Auto Mode (Recommended)

```bash
./scripts/local-dev-setup.sh
```

The script detects if you already have configuration files:
- **If NO files exist** → Creates fresh from templates (same as `-new`)
- **If files exist** → Asks you to choose between:
  - `1` - Create fresh (overwrites existing)
  - `2` - Merge (preserves existing values)

Default: `2` (merge)

---

### New Mode (`-new`)

Create fresh configuration files from templates:

```bash
./scripts/local-dev-setup.sh -new
```

**Use when:**
- First time setup
- You want to start completely fresh
- You don't need to preserve existing values

**What it does:**
- Copies `all.yml.example` → `all.yml`
- Copies `vault.yml.example` → `vault.yml`
- Ready for you to edit

---

### Merge Mode (`-merge`)

Merge existing configuration with updated templates:

```bash
./scripts/local-dev-setup.sh -merge
```

**Use when:**
- Templates were updated with bug fixes or new features
- You want to keep your existing values
- You only want to add NEW configuration items

**What it does:**
- Creates backups with timestamps
- Decrypts vault (if encrypted)
- Merges your existing values into new templates
- Shows you what changed
- Leaves vault unencrypted (ready to edit)

---

## Detailed Workflow

### First Time Setup

```bash
cd deployment

# 1. Create fresh configuration
./scripts/local-dev-setup.sh -new

# 2. Edit your configuration
nano group_vars/all.yml
nano group_vars/vault.yml

# 3. Create vault password (optional but recommended)
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# 4. Encrypt the vault
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default

# 5. Configure git
./scripts/configure-git.sh

# 6. Deploy
./scripts/infra-complete-setup.sh
```

---

### Template Update Workflow

```bash
# 1. Pull latest templates from git
git pull origin main

# 2. Check if all.yml.example or vault.yml.example changed
git diff group_vars/all.yml.example
git diff group_vars/vault.yml.example

# 3. Merge your existing config with updated templates
./scripts/local-dev-setup.sh -merge

# 4. Review what changed
nano group_vars/all.yml    # Look for new values
nano group_vars/vault.yml

# 5. Add any NEW values from the templates

# 6. Encrypt the vault
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default

# 7. Deploy with new configuration
./scripts/infra-complete-setup.sh
```

---

## Vault Password File

The script handles vault encryption/decryption automatically:

- **If `~/.vault_pass` exists** - Uses it (no prompt)
- **If missing** - Prompts you to enter password
- **After merge** - Vault is left unencrypted (ready to edit)

**Create the file for convenience:**
```bash
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

---

## Backups

When using `-merge` mode, the script creates timestamped backups:

```bash
# Backup locations
group_vars/all.yml.backup.1708632706
group_vars/vault.yml.backup.1708632706
group_vars/vault.yml.decrypted.1708632706  # If vault was encrypted
```

**Restore if needed:**
```bash
cp group_vars/all.yml.backup.1708632706 group_vars/all.yml
cp group_vars/vault.yml.backup.1708632706 group_vars/vault.yml
```

**Skip backups (if confident):**
```bash
./scripts/local-dev-setup.sh -merge --no-backup
```

---

## Troubleshooting

### "Vault password file not found"

The script will prompt you:

```bash
./scripts/local-dev-setup.sh -merge

# Output:
# 🔓 Decrypting vault.yml...
#    Vault password file not found. Please enter your vault password:
#    Vault password: [type your password]
```

To avoid prompts, create the file:

```bash
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

### "Permission denied"

Make sure script is executable:

```bash
chmod +x deployment/scripts/local-dev-setup.sh
```

### "No existing files found" with `-merge`

The script will create fresh files instead:

```bash
./scripts/local-dev-setup.sh -merge

# No existing files? Creates from template
# ✅ Created: all.yml
# ✅ Created: vault.yml
```

---

## Why One Script?

Instead of maintaining two separate scripts (`local-dev-setup.sh` and `merge-config.sh`), we have one unified script that:

- ✅ Detects your situation automatically
- ✅ Handles both new setup and merging
- ✅ Reduces code duplication
- ✅ Easier to maintain
- ✅ Clear and consistent interface

Both workflows are now seamless with the same tool.

---

## Tips

1. **Run merge after template updates**
   ```bash
   git pull origin main
   ./scripts/local-dev-setup.sh -merge
   ```

2. **Check what changed in templates**
   ```bash
   git diff group_vars/*.example
   ```

3. **Vault stays unencrypted after merge**
   - Good: Easy to edit
   - Remember: Encrypt before deploying
   ```bash
   ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default
   ```

4. **Multiple projects?**
   - Use `-merge` for each project after template updates
   - Automatically preserves your project-specific values
