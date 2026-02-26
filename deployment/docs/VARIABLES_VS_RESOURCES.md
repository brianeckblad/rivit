# Variables vs AWS Resources - Important Distinction

**Date:** February 25, 2026  
**Status:** ✅ CLARIFIED

---

## The Confusion

After running `source scripts/load-vars.sh`, the documentation said:

```
Variables are NOW AVAILABLE in your shell. Try these commands:
  echo $app_name
  aws s3 ls | grep $app_name
  aws iam get-role --role-name ${app_name}-ec2-role
```

This was misleading because it grouped together things that work now with things that will FAIL.

---

## The Important Distinction

### ✅ Variables ARE Available NOW

These work immediately after `source scripts/load-vars.sh`:

```bash
echo $app_name              # ✅ Works - outputs: rampe
echo $aws_region            # ✅ Works - outputs: us-east-2
echo $admin_user            # ✅ Works - outputs: ubuntu
echo $server_name           # ✅ Works - outputs: rampe.ipix.io
echo $app_display_name      # ✅ Works - outputs: Rampe Inventory Manager
```

**Why?** These are just configuration values loaded from `group_vars/all.yml`.

### ❌ AWS Resources Do NOT Exist Yet

These will FAIL because the resources haven't been created:

```bash
aws s3 ls | grep $app_name
# ❌ FAILS - S3 bucket doesn't exist yet

aws iam get-role --role-name ${app_name}-ec2-role
# ❌ FAILS - IAM role doesn't exist yet

aws ec2 describe-security-groups --group-names ${app_name}-sg
# ❌ FAILS - Security group doesn't exist yet
```

**Why?** These AWS resources are created during the deployment playbooks. They don't exist yet!

---

## Timeline

### Stage 1: Now (Load Variables)
```
✅ Variables loaded from group_vars/all.yml
✅ Configuration values available in shell
❌ AWS resources don't exist yet
```

### Stage 2: During Deployment (Run Playbooks)
```
✅ Variables still available
✅ Playbooks create AWS resources using variables
✅ Resources are created/configured based on variables
```

### Stage 3: After Deployment (Resources Exist)
```
✅ Variables available
✅ AWS resources now exist
✅ AWS CLI commands using variables will work
```

---

## What Variables Are For

Variables are used by:

1. **Deployment Scripts**
   - Pass configuration to playbooks
   - Reference app names, regions, etc.
   - Example: `ansible-playbook ... --extra-vars "app_name=$app_name"`

2. **Deployment Playbooks**
   - Create resources named after app (e.g., S3 bucket with app name)
   - Deploy to specified region
   - Set up users and permissions
   - Example: S3 bucket creation uses `{{ app_name }}-data`

3. **Manual CLI Commands** (AFTER deployment)
   - Reference resources after they're created
   - Example: `aws s3 ls | grep $app_name` (works after S3 bucket created)

---

## Key Point

**Variables are CONFIGURATION, not proof that resources exist.**

Think of variables like a recipe ingredient list:
- ✅ You have the list of ingredients (variables)
- ❌ You haven't made the cake yet (resources)
- After you follow the recipe (run deployment), the cake exists

---

## Updated Documentation

The MANUAL_DEPLOYMENT.md has been updated to show:

### What Works NOW:
```bash
# Configuration variables (from group_vars/all.yml)
echo $app_name
echo $aws_region
echo $admin_user
```

### What Fails NOW (but works after deployment):
```bash
# AWS resources (created by playbooks)
aws s3 ls | grep $app_name
aws iam get-role --role-name ${app_name}-ec2-role
aws ec2 describe-security-groups
```

### Clear Labels:
- ✅ Works NOW (just configuration)
- ❌ Fails NOW (resources don't exist)
- After deployment playbooks, all work!

---

## When These Commands Work

| Command | Now | After Deployment |
|---------|-----|------------------|
| `echo $app_name` | ✅ | ✅ |
| `echo $aws_region` | ✅ | ✅ |
| `aws s3 ls` | ✅ | ✅ |
| `aws s3 ls \| grep $app_name` | ❌ | ✅ |
| `aws iam get-role --role-name ${app_name}-ec2-role` | ❌ | ✅ |
| `aws ec2 describe-instances` | ✅ | ✅ |
| `aws ec2 describe-instances --filter "tag:Name=${app_name}"` | ❌ | ✅ |

---

## Summary

✅ **Variables are loaded immediately** - they're configuration values  
❌ **AWS resources don't exist yet** - they're created during deployment  
✅ **After deployment, all commands work** - resources now exist

This is the correct sequence:
1. Load variables (configuration)
2. Run deployment playbooks (create resources)
3. Use variables with AWS CLI (resources now exist)


