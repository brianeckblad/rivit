# load-vars.sh Usage Guide

## The Problem

When you tried to run the script directly, variables were not available in your shell:

```bash
(.venv) brian@einstein rampe % deployment/scripts/load-vars.sh
# Script ran but variables not available in shell
```

## The Solution

**You must `source` the script, not run it directly.**

The key difference:

| Method | Result |
|--------|--------|
| `./scripts/load-vars.sh` | ❌ Script runs in subshell, variables not available to you |
| `source scripts/load-vars.sh` | ✅ Script runs in your shell, variables exported and available |

---

## Correct Usage

### Step 1: Navigate to deployment directory
```bash
cd deployment
```

### Step 2: Source the script (IMPORTANT - use `source`)
```bash
source scripts/load-vars.sh
```

### Step 3: Verify variables are exported
```bash
echo $app_name
# Output: rampe

echo $aws_region
# Output: us-east-2
```

### Step 4: Use variables in commands
```bash
# Now all these work:
aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
aws ec2 describe-security-groups --group-names ${app_name}-sg
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
```

---

## Expected Output

When you source the script correctly:

```bash
$ cd deployment
$ source scripts/load-vars.sh

✅ Variables loaded and EXPORTED successfully

Available variables (exported to this shell):
  app_name=rampe
  app_display_name=Rampe Application
  aws_region=us-east-2
  admin_user=ubuntu
  server_name=rampe.ipix.io

Variables are NOW AVAILABLE in your shell. Try these commands:
  echo $app_name
  aws s3 ls | grep $app_name
  aws iam get-role --role-name ${app_name}-ec2-role

List all exported variables:
  env | grep -E '^(app_|aws_|admin_)' | sort

ℹ️  Note: vault.yml is encrypted
Sensitive variables from vault.yml will not be available in shell.

For CLI commands that need vault variables:
  1. Use Ansible playbooks: ansible-playbook playbooks/... --vault-password-file ~/.vault_pass
  2. Or view vault manually: ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass
```

---

## What Gets Exported

After sourcing, these variables are available in your shell:

**From `group_vars/all.yml`:**
```bash
$app_name                # rampe
$app_display_name        # Rampe Application
$aws_region              # us-east-2
$admin_user              # ubuntu
$server_name             # rampe.ipix.io
# ... and all other simple string/number variables
```

**From `group_vars/vault.yml` (only if not encrypted):**
- Sensitive variables like API keys, passwords
- (Skipped if vault is encrypted - use playbooks for those)

---

## Using in CLI Commands

Once variables are exported, you can use them immediately:

### AWS S3
```bash
# List S3 buckets filtered by app name
aws s3 ls | grep $app_name

# Create bucket with app name
aws s3api create-bucket \
    --bucket ${app_name}-data \
    --region $aws_region
```

### AWS IAM
```bash
# Get IAM role info
aws iam get-role --role-name ${app_name}-ec2-role

# Get instance profile
aws iam get-instance-profile \
    --instance-profile-name ${app_name}-ec2-profile
```

### AWS EC2
```bash
# Describe security group
aws ec2 describe-security-groups \
    --group-names ${app_name}-sg

# Describe instances with tag
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}-server"

# SSH to server
ssh -i ~/.ssh/${app_name}-key.pem ubuntu@$SERVER_IP
```

### View all exported variables
```bash
env | grep -E '^(app_|aws_|admin_)' | sort
```

---

## Troubleshooting

### Problem: "command not found: $app_name"

**Cause:** You ran the script directly instead of sourcing it.

**Fix:**
```bash
# Wrong:
./scripts/load-vars.sh

# Correct:
source scripts/load-vars.sh
```

### Problem: Variables not available in new terminal tab

**Cause:** Each terminal session needs to source the script.

**Fix:**
```bash
# Run in each new terminal tab:
cd deployment
source scripts/load-vars.sh
```

### Problem: "app_name=" (blank value)

**Cause:** Variables didn't load from all.yml

**Fix:**
1. Verify `group_vars/all.yml` exists:
   ```bash
   cat group_vars/all.yml | grep "^app_name:"
   ```

2. Verify the value:
   ```bash
   grep "^app_name:" group_vars/all.yml
   # Should show: app_name: "rampe"
   ```

3. Source again:
   ```bash
   source scripts/load-vars.sh
   ```

---

## How It Works

1. **Script reads** `group_vars/all.yml` line by line
2. **Parses** simple key: value pairs using bash regex
3. **Skips** complex values (Jinja2 templates, lists, dicts)
4. **Exports** each variable using `export KEY="value"`
5. **Displays** what was loaded and available

---

## One-Time Setup

You only need to source once per terminal session:

```bash
cd deployment
source scripts/load-vars.sh

# Now use variables for any number of commands:
echo $app_name
aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
# ... all work without sourcing again
```

---

## Using in Deployment Guide

All CLI examples in MANUAL_DEPLOYMENT.md assume you've sourced this script:

```bash
cd deployment
source scripts/load-vars.sh

# Then all commands like this work:
aws s3api create-bucket \
    --bucket ${app_name}-data \
    --region $aws_region
```

---

## Shell Compatibility

✅ Works with bash 3.0+  
✅ Works with zsh  
✅ Works with any POSIX shell  
✅ Pure bash - no external dependencies  

---

## Security Notes

✅ **Never** commits secrets to git  
✅ **Only** exports simple non-sensitive variables  
✅ **Vault** variables remain encrypted (not exported)  
✅ **User** credentials not exposed in environment  


