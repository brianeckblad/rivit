# Variable Loading Implementation Summary

**Date:** February 24, 2026  
**Status:** ✅ Complete

## What Was Done

Updated all deployment documentation to show how to load and use configuration variables in CLI commands.

### Files Created

1. **`deployment/scripts/load-vars.sh`**
   - Parses `all.yml` and `vault.yml` for configuration variables
   - Exports variables for use in shell commands
   - Displays available variables and usage examples
   - Warns if vault is encrypted or unencrypted
   - Makes variables like `$app_name`, `$aws_region` available

### Files Updated

1. **`MANUAL_DEPLOYMENT.md`** - Complete rewrite of CLI sections
   - Added "Load Configuration Variables" section at top
   - Updated ALL CLI commands to use shell variables
   - Shows how to run: `source scripts/load-vars.sh`
   - All S3, IAM, EC2 commands now use: `${app_name}`, `${aws_region}`, etc.

2. **`QUICKSTART.md`** - Updated deployment section
   - Added variable loading instructions
   - Shows playbook usage with variables

3. **`PREREQUISITES.md`** - Updated verification checklist
   - Added step to verify variables load correctly
   - Shows: `source scripts/load-vars.sh`

## How It Works

### For Users

**Step 1: Load variables**
```bash
cd deployment
source scripts/load-vars.sh
```

**Step 2: Variables are now available**
```bash
echo $app_name           # Shows: rampe
echo $aws_region         # Shows: us-east-2

# Use in CLI commands
aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
```

### What Variables Are Available

**From `all.yml` (auto-loaded):**
- `app_name` - Application technical name
- `app_display_name` - Display name
- `aws_region` - AWS region
- `admin_user` - Admin SSH user
- `server_name` - Domain name or "_"
- And many others...

**From `vault.yml`:**
- NOT loaded into shell (encrypted)
- Use playbooks instead for commands needing vault secrets
- Example: `ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass`

## CLI Command Updates

### Before (Placeholder style):
```bash
aws s3 ls | grep {app_name}
aws iam get-role --role-name {app_name}-ec2-role
```

### After (Variable style):
```bash
source scripts/load-vars.sh

aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
```

## Benefits

1. **Real Values** - CLI commands use actual configuration, not placeholders
2. **Copy-Paste Ready** - Users can copy commands directly from docs
3. **Automatic Substitution** - No manual find-and-replace needed
4. **Single Source of Truth** - All values come from `all.yml`
5. **Vault Integration** - Works seamlessly with encrypted secrets
6. **User Feedback** - Script shows which variables are available
7. **Error Prevention** - Warns about unencrypted vaults

## Documentation Structure

```
Prerequisites
  ↓
  Load variables with: source scripts/load-vars.sh
  ↓
Automated Deployment (QUICKSTART.md)
  ↓
  Run playbooks with variables available
  ↓
Manual Deployment (MANUAL_DEPLOYMENT.md)
  ↓
  All CLI commands use: $app_name, $aws_region, etc.
```

## Files Mentioned in Docs

| File | Purpose |
|------|---------|
| `group_vars/all.yml` | Main configuration variables |
| `group_vars/vault.yml` | Encrypted secrets |
| `scripts/load-vars.sh` | Loads vars into shell session |
| `deployment/instance-info.txt` | Saved after EC2 launch |

## Example Workflow

```bash
# 1. Go to deployment directory
cd deployment

# 2. Create and configure
./scripts/local-dev-setup.sh

# 3. Load variables
source scripts/load-vars.sh

# 4. View available variables
echo "App: $app_name in region $aws_region"

# 5. Now use in ANY command
aws s3 ls | grep $app_name
aws iam get-instance-profile --instance-profile-name ${app_name}-ec2-profile
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
```

## One-Time Setup

Users need to do this once:

```bash
# 1. Create vault password file
echo "your-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# 2. Encrypt vault (if not already encrypted)
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass

# 3. Done! Now run:
source scripts/load-vars.sh
# And variables are ready to use
```

## Testing

The script works correctly when:

✅ `source scripts/load-vars.sh` shows "Variables loaded successfully"  
✅ `echo $app_name` displays the configured app name  
✅ `env | grep app_name` shows the exported variable  
✅ AWS CLI commands use variables without errors  

## Security

- Vault variables are NOT exported to shell (remains secure)
- Only non-vault variables are available in CLI
- For vault secrets, use playbooks with `--vault-password-file`
- Vault password protected with 600 permissions

## Links in Documentation

- [MANUAL_DEPLOYMENT.md](docs/guides/MANUAL_DEPLOYMENT.md) - Detailed CLI commands with variables
- [QUICKSTART.md](docs/guides/QUICKSTART.md) - Quick deployment with variables
- [PREREQUISITES.md](docs/guides/PREREQUISITES.md) - Setup and verification with variable loading
- [VAULT_PASSWORD_USAGE.md](docs/guides/VAULT_PASSWORD_USAGE.md) - How vault decryption works

## Commits

✅ All changes committed and pushed to GitHub  
✅ Files ready for deployment documentation


