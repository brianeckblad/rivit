# Configuration Merge Tool

**Update templates while keeping your existing configuration**

---

## Problem It Solves

When you update your templates (`all.yml.example`, `vault.yml.example`) because you found bugs or added features, you don't want to lose your existing configuration. You just want to add the new values.

**Before (tedious):**
```
1. Get new all.yml.example and vault.yml.example
2. Manually copy all your old values into new files
3. Add new values from the template
4. Repeat for every template update
```

**After (automatic):**
```
1. Run merge-config.sh
2. It imports your existing values automatically
3. New template values are ready to configure
4. Just add the new stuff
```

---

## Quick Start

```bash
cd deployment
./scripts/merge-config.sh
```

**That's it!** Your existing configuration is merged into the new templates.

---

## What It Does

1. **Finds existing files** - Looks for your current `all.yml` and `vault.yml`
2. **Creates backups** - Saves copies with timestamp before making changes
3. **Decrypts vault** (if needed) - If vault is encrypted, decrypts it temporarily
4. **Merges values** - Copies all your existing values into new template files
5. **Keeps vault unencrypted** - You can edit immediately without encryption/decryption
6. **Shows next steps** - Clear instructions on what to do next

---

## Usage Examples

### Example 1: Basic Merge (Default)

```bash
./scripts/merge-config.sh
```

**What happens:**
- ✅ Creates backups with timestamps
- ✅ Decrypts vault if encrypted
- ✅ Merges your values into new templates
- ✅ Leaves vault unencrypted for editing

### Example 2: Skip Backup Creation

```bash
./scripts/merge-config.sh --no-backup
```

**When to use:**
- You're confident in the changes
- You've already backed up manually
- You just want the merge to happen faster

### Example 3: Force Without Confirmation

```bash
./scripts/merge-config.sh --force
```

**When to use:**
- Running in automation/scripts
- You know what you're doing
- Don't show prompts

---

## Backup Location

Backups are created in `deployment/group_vars/`:

```bash
# Backup files look like:
all.yml.backup.1708632706
vault.yml.backup.1708632706
vault.yml.decrypted.1708632706  # If vault was encrypted
```

**View backups:**
```bash
ls -lh deployment/group_vars/*.backup*
ls -lh deployment/group_vars/*.decrypted*
```

**Restore from backup (if needed):**
```bash
cp deployment/group_vars/all.yml.backup.1708632706 deployment/group_vars/all.yml
cp deployment/group_vars/vault.yml.backup.1708632706 deployment/group_vars/vault.yml
```

---

## After Merge - Next Steps

### 1. Review the Merged Files

```bash
# Check all.yml for new values
nano deployment/group_vars/all.yml

# Check vault.yml for new values
nano deployment/group_vars/vault.yml
```

**Look for:**
- Comments indicating new fields
- Template variables that need values
- Any fields marked as "CHANGE THIS"

### 2. Add New Configuration Values

Find any new fields from the template that weren't in your old file and add them.

### 3. Encrypt the Vault (When Done)

```bash
cd deployment
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default
```

### 4. Deploy

```bash
./scripts/infra-complete-setup.sh
```

---

## Workflow Example

**Scenario:** You discover a bug and update `all.yml.example` with new configuration.

```bash
# 1. You update the template in the repo
git pull origin main

# 2. Merge your existing config with the new template
./scripts/merge-config.sh

# Output:
# ✅ Found: all.yml (will merge values)
# ✅ Found: vault.yml (will merge values)
# ✅ Backed up: all.yml → all.yml.backup.1708632706
# ✅ Backed up: vault.yml → vault.yml.backup.1708632706
# ✅ Merged existing values into all.yml
# ✅ Merged existing values into vault.yml
# 
# Your existing values have been merged into the new templates.
# Only NEW values (from template updates) need to be configured.

# 3. Edit to add any new values
nano group_vars/all.yml

# 4. Encrypt vault
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default

# 5. Deploy
./scripts/infra-complete-setup.sh
```

---

## Vault Handling

### If Your Vault Is Encrypted

The script automatically:
1. Detects that vault.yml is encrypted
2. Decrypts it temporarily
3. Extracts your values
4. Merges them into new template
5. Leaves new vault.yml **unencrypted** (so you can edit easily)

**Important:** After merging and editing, you must re-encrypt:

```bash
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass --encrypt-vault-id default
```

### If Your Vault Is Unencrypted

The script just merges the values - no decryption needed.

---

## Troubleshooting

### "Vault password file not found"

```bash
# Create it
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Then try merge again
./scripts/merge-config.sh
```

### "Permission denied"

```bash
# Make script executable
chmod +x scripts/merge-config.sh

# Then run again
./scripts/merge-config.sh
```

### "No existing files found"

This means neither `all.yml` nor `vault.yml` exists yet.

The script will create both from templates:

```bash
✅ Created: all.yml
✅ Created: vault.yml (unencrypted, ready to edit)
```

Then edit them normally:
```bash
nano group_vars/all.yml
nano group_vars/vault.yml
```

### "Merged file has wrong values"

Restore from backup:

```bash
# List available backups
ls -lh deployment/group_vars/*.backup*

# Restore
cp deployment/group_vars/all.yml.backup.1708632706 deployment/group_vars/all.yml
cp deployment/group_vars/vault.yml.backup.1708632706 deployment/group_vars/vault.yml

# Try merge again
./scripts/merge-config.sh
```

---

## Script Behavior Summary

| Scenario | Behavior |
|----------|----------|
| First time run | Creates new files from templates |
| Update templates | Merges old values + new template |
| Vault encrypted | Temporarily decrypts, then leaves unencrypted |
| Vault unencrypted | Just merges values, no decryption |
| Files exist | Backs up before modifying |
| `--no-backup` | Skips backup creation |
| `--force` | No confirmation prompts |

---

## Integration with Other Scripts

Works perfectly with:

- **`local-dev-setup.sh`** - Initial setup (creates new files)
- **`merge-config.sh`** - Update workflow (merges existing + new)
- **`configure-git.sh`** - Git configuration
- **`infra-complete-setup.sh`** - Deployment

**Typical workflow:**

```bash
# First time
./scripts/local-dev-setup.sh

# Later, when templates are updated
./scripts/merge-config.sh

# Configure git
./scripts/configure-git.sh

# Deploy
./scripts/infra-complete-setup.sh
```

---

## Tips

1. **Run merge-config after pulling updates**
   ```bash
   git pull origin main
   ./scripts/merge-config.sh  # Merge template changes with your config
   ```

2. **Keep old backups for comparison**
   ```bash
   # Old backup still has your original values
   diff deployment/group_vars/all.yml.backup.* deployment/group_vars/all.yml
   ```

3. **Vault stays unencrypted after merge**
   - Good for editing
   - Bad for security if you commit
   - **Don't forget to encrypt:** `ansible-vault encrypt ...`

4. **Check what changed**
   ```bash
   # See all new/changed values
   diff deployment/group_vars/all.yml.example deployment/group_vars/all.yml
   ```

---

## Why This Matters

Without merge-config, you'd have to:
- ❌ Manually retype all your configuration
- ❌ Risk losing values
- ❌ Spend time on tedious copying
- ❌ Deal with vault encryption/decryption manually

With merge-config:
- ✅ Automatic value preservation
- ✅ Quick template updates
- ✅ Clear workflow
- ✅ Safe backups included
- ✅ Vault handled automatically

