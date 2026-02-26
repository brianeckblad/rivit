# Fix Summary: load-vars.sh Regex Errors

**Date:** February 24, 2026  
**Status:** ✅ FIXED

---

## Problem

When running `source scripts/load-vars.sh`, user got repeated errors:

```
parse_yaml_simple:16: failed to compile regex: brackets ([ ]) not balanced
```

This was repeated 30+ times, making the output noisy even though variables eventually loaded.

---

## Root Cause

The YAML parser function used complex regex patterns with escaping for square brackets:

```bash
[[ "$value" =~ \[\[ ]]    # ❌ Unbalanced brackets in regex
[[ "$value" =~ ^\[\{* ]]  # ❌ Confusing bracket escaping
```

Bash regex requires proper escaping, and the `[[ ]]` pattern was being misinterpreted.

---

## Solution

**Removed complex regex escaping** and replaced with simple string operations:

```bash
# Before (causes regex errors):
[[ "$value" =~ \[\[ ]] && continue
[[ "$value" =~ ^\[\{* ]] && continue

# After (clean and simple):
if [[ "$value" == *"{{"* ]] || [[ "$value" == *"}}"* ]] || \
   [[ "$value" == "["* ]] || [[ "$value" == "{"* ]]; then
    continue
fi
```

**Also improved value extraction:**

```bash
# Remove inline comments
value="${value%% #*}"

# Remove quotes
value="${value//\"/}"
value="${value//\'/}"

# Trim whitespace with sed
value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
```

---

## Results

### ✅ Before Fix
```
parse_yaml_simple:16: failed to compile regex: brackets ([ ]) not balanced
parse_yaml_simple:16: failed to compile regex: brackets ([ ]) not balanced
....(repeated 30+ times)
app_name=
aws_region=
admin_user=
```

### ✅ After Fix
```
✅ Variables loaded and EXPORTED successfully

Available variables (exported to this shell):
  app_name=rampe
  app_display_name=Rampe Inventory Manager
  aws_region=                              # Note: Jinja2 values need Ansible
  admin_user=ubuntu
  server_name=rampe.ipix.io

Variables are NOW AVAILABLE in your shell...
```

---

## What Now Works

✅ **No regex errors** - Clean parsing without bracket escaping issues  
✅ **Variables load** - All simple string values extracted correctly  
✅ **Comments removed** - Inline comments properly stripped  
✅ **Quotes handled** - Both single and double quotes removed  
✅ **Whitespace trimmed** - Leading/trailing spaces removed  

---

## Variables That Work

From `group_vars/all.yml`:

✅ `app_name=rampe`  
✅ `app_display_name=Rampe Inventory Manager`  
✅ `admin_user=ubuntu`  
✅ `server_name=rampe.ipix.io`  

❓ `aws_region=` (Jinja2 value - requires Ansible)  
❓ `app_user=` (Jinja2 value - requires Ansible)  
❓ `app_storage_mount_path=` (Jinja2 value - requires Ansible)  

**Note:** Jinja2 variables like `"{{ vault_aws_region | default('us-east-2') }}"` are intentionally skipped because they need Ansible template processing. Use playbooks for these.

---

## Files Modified

- **deployment/scripts/load-vars.sh**
  - Removed complex regex patterns
  - Simplified value extraction
  - Improved comment removal
  - Better whitespace handling

---

## Testing

```bash
cd deployment/
source scripts/load-vars.sh

# These now work:
echo $app_name          # Shows: rampe
echo $admin_user        # Shows: ubuntu
echo $server_name       # Shows: rampe.ipix.io

# These will be empty (Jinja2 - use playbooks):
echo $aws_region        # Empty (use: ansible-playbook ... --vault-password-file ~/.vault_pass)
```

---

## Status

✅ **NO MORE REGEX ERRORS**  
✅ **VARIABLES LOAD CORRECTLY**  
✅ **CLEAN OUTPUT**  

The script now works as expected!


