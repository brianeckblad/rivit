# Chapter 3: Manual Deployment

Deploy step-by-step with full explanations.

> **Prerequisite:** Complete [Chapter 1: Prerequisites](PREREQUISITES.md) before continuing.

---

## Load Configuration Variables

CLI commands in this guide use `$app_name`, `$aws_region`, and other variables from `group_vars/vault.yml`. Load them once per terminal session:

```bash
cd deployment
source scripts/load-vars.sh
```

Verify:

```bash
echo $app_name       # e.g., rivit
echo $aws_region     # e.g., us-east-2
```

---

## Architecture

```
Your Local Machine
       ↓ ansible-playbook playbooks/provision-app.yml
┌─────────────────────────────────────────┐
│   AWS (us-east-2)                       │
│                                         │
│   S3 Bucket          ← app data/images  │
│   Secrets Manager    ← config secrets   │
│   IAM Policies       ← attached to      │
│                         ↓               │
│   Shared EC2 Server (pre-existing)      │
│   - IAM Instance Role                   │
└─────────────────────────────────────────┘
       ↓ ansible-playbook playbooks/setup.yml
┌─────────────────────────────────────────┐
│   Shared Server (SSH target)            │
│                                         │
│   /opt/{app_name}/       ← code + venv  │
│   /var/log/{app_name}/   ← logs         │
│   Supervisor             ← process mgr  │
│   Nginx vhost            ← web server   │
│   SSL cert (Let's Encrypt)              │
└─────────────────────────────────────────┘
```

---

## Step 1: Create S3 Bucket

**Playbook:**
```bash
ansible-playbook playbooks/create-s3-bucket.yml --vault-password-file ~/.vault_pass
```

**CLI:**
```bash
aws s3api create-bucket \
    --bucket $s3_bucket_name \
    --region $aws_region \
    --create-bucket-configuration LocationConstraint=$aws_region

# Block public access
aws s3api put-public-access-block \
    --bucket $s3_bucket_name \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable versioning (for backups)
aws s3api put-bucket-versioning \
    --bucket $s3_bucket_name \
    --versioning-configuration Status=Enabled
```

**What it creates:**

| Setting | Value |
|---------|-------|
| Bucket name | `{s3_bucket_name}` from vault.yml |
| Region | `{aws_region}` |
| Versioning | Enabled (for point-in-time restore) |
| Public access | Blocked |
| Encryption | AES256 server-side |

---

## Step 2: Create IAM Policies

Creates three app-scoped managed policies that grant the server access to this app's resources only.

**Playbook:**
```bash
ansible-playbook playbooks/create-iam-policies.yml --vault-password-file ~/.vault_pass
```

**What it creates:**

| Policy name | Grants access to |
|-------------|-----------------|
| `{app_name}-s3-access` | The app's S3 bucket only |
| `{app_name}-secrets-access` | Secrets under `{app_name}/` prefix only |
| `{app_name}-cloudwatch-access` | CloudWatch metrics and logs |

If `server_iam_role_name` is set in vault.yml, the policies are automatically attached to the shared server's IAM role. Otherwise, attach them manually in the IAM console.

**Re-attach manually (if needed):**
```bash
# Find your policies
aws iam list-policies --query "Policies[?starts_with(PolicyName, '$app_name')]" --output table

# Attach to role
aws iam attach-role-policy \
    --role-name <shared-server-role> \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${app_name}-s3-access
```

---

## Step 3: Create Secrets Manager Secret

Pushes all vault secrets to AWS Secrets Manager so the app reads them at runtime.

**Playbook:**
```bash
ansible-playbook playbooks/setup-secrets-manager.yml --vault-password-file ~/.vault_pass
```

**CLI:**
```bash
# Create the secret
aws secretsmanager create-secret \
    --name ${app_name}/production \
    --description "Secrets for ${app_name}" \
    --region $aws_region
```

---

## Step 4: Deploy Application to Server

Deploys code, virtualenv, supervisor, nginx, and SSL to the shared server.

**Playbook:**
```bash
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
```

This single playbook:

1. Creates the app user and group (`{app_user}`, `{app_name}`)
2. Creates `/opt/{app_name}/` and `/var/log/{app_name}/`
3. Clones the git repo into `/opt/{app_name}/`
4. Creates a Python virtualenv and installs requirements
5. Writes `/etc/supervisor/conf.d/{app_name}.conf`
6. Writes `/etc/nginx/sites-available/{app_name}` and enables the vhost
7. Obtains an SSL certificate via Let's Encrypt
8. Starts the application under Supervisor

**Verify:**
```bash
ssh ubuntu@<server-ip>
sudo supervisorctl status {app_name}     # Should show RUNNING
curl https://{server_name}               # Should return 200
```

---

## Step 5: CloudFront CDN (optional)

Only needed if `enable_cloudfront: true` in vault.yml.

**Playbook:**
```bash
ansible-playbook playbooks/setup-cloudfront.yml --vault-password-file ~/.vault_pass
```

After this runs, copy the CloudFront domain from the output into `cloudfront_domain` in vault.yml, then sync secrets:

```bash
ansible-playbook playbooks/secret-sync.yml --vault-password-file ~/.vault_pass
```

---

## Verify Deployment

```bash
# Application running?
ssh ubuntu@<server-ip>
sudo supervisorctl status {app_name}

# Logs clean?
sudo tail -20 /var/log/{app_name}/app.log

# HTTPS working?
curl -I https://{server_name}

# HTTP redirects to HTTPS?
curl -I http://{server_name}
```

---

## Next step

Continue to [Chapter 4: Updating Your Application](UPDATING_APPLICATION.md).

## See also

- [Chapter 5: Operations](OPERATIONS.md) — backups, restarts, scaling
- [Chapter 7: Secret Management](SECRET_MANAGEMENT.md) — rotate and sync secrets
