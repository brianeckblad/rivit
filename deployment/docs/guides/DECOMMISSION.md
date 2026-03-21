# Chapter 13: Decommission

Remove all AWS resources — full teardown or single-resource rollback.

> **Warning:** This is destructive and irreversible. All data in S3, EC2 instances, and associated resources will be permanently deleted.

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [Full Automated Teardown](#full-automated-teardown) (Option A — 5 minutes)
3. [Step-by-Step Teardown](#step-by-step-teardown) (Option B — per resource)
   - [Step 1: Terminate EC2 Instance](#step-1-terminate-ec2-instance)
   - [Step 2: Delete SSH Key Pair](#step-2-delete-ssh-key-pair)
   - [Step 3: Delete Security Group](#step-3-delete-security-group)
   - [Step 4: Delete IAM Role + Policies](#step-4-delete-iam-role--policies)
   - [Step 5: Delete S3 Bucket](#step-5-delete-s3-bucket)
   - [Step 6: Delete Secrets Manager Secret](#step-6-delete-secrets-manager-secret)
   - [Step 7: Delete WAF (optional)](#step-7-delete-waf-optional)
   - [Step 8: Delete CloudFront (optional)](#step-8-delete-cloudfront-optional)
4. [Verify Everything Is Gone](#verify-everything-is-gone)
5. [Single Resource Rollback](#single-resource-rollback)
6. [Troubleshooting](#troubleshooting)
7. [See also](#see-also)

---

## Before You Begin

### Pre-Decommission Checklist

```
Before deleting anything, confirm:

  [ ] All application data has been backed up
  [ ] All logs have been archived
  [ ] Users have been notified of the shutdown
  [ ] You have the vault password (needed for playbooks)
  [ ] You know your S3 bucket name (from vault)
```

→ **Full backup procedure:** [OPERATIONS.md — Server Decommissioning](OPERATIONS.md#server-decommissioning)

### Dependency Order

Resources must be deleted in **reverse order** of creation. The EC2 instance depends on most other resources, so it goes first:

```
CREATE ORDER                    DELETE ORDER (reverse)
─────────────                   ─────────────────────
1. S3 Bucket                    1. EC2 Instance  ← must go first
2. IAM Role + Policies          2. SSH Key Pair
3. Security Group               3. Security Group  ← blocked while EC2 uses it
4. SSH Key Pair                 4. IAM Role        ← blocked while EC2 uses it
5. EC2 Instance                 5. S3 Bucket       ← data lost forever

Optional features:              Optional features:
6. Secrets Manager              6. WAF             ← if configured
7. CloudFront                   7. CloudFront      ← takes 15 min to disable
8. WAF                          8. Secrets Manager ← if configured
```

### Load Variables

All commands below require your deployment variables:

```bash
cd deployment
source scripts/load-vars.sh
```

---

## Full Automated Teardown

**Removes everything with one command (5 minutes)**

```bash
cd deployment
./scripts/decommission.sh
```

The script presents a discovery menu:

| Choice | What it does |
|--------|-------------|
| **1) Query AWS** | Checks for live EC2 instances. Exits cleanly if none found. |
| **2) New deployment** | Exits immediately — nothing to tear down. |

When resources are found, the script asks you to type the app name to confirm, then calls the decommission playbook.

> **Direct playbook usage (advanced):** If you want to skip the discovery menu:
> ```bash
> ansible-playbook playbooks/decommission.yml --vault-password-file ~/.vault_pass -e decommission_confirmed=true
> ```

**What it does (in order):**

| Step | Playbook Called | What Gets Deleted |
|------|----------------|-------------------|
| 1 | `terminate-ec2-instance.yml` | EC2 instance + local info file |
| 2 | `delete-ssh-key.yml` | AWS key pair + local `.pem` file |
| 3 | `delete-security-group.yml` | Security group (retries if dependency lingers) |
| 4 | `delete-iam-role.yml` | Inline policies, managed policies, all instance profiles, role |
| 5 | `delete-s3-bucket.yml` | All objects, versions, delete markers, then bucket (prompts YES) |
| 6a | `delete-waf.yml` | Web ACL, IP set, ALB association (skips if not configured) |
| 6b | `delete-cloudfront.yml` | Distribution, OAI, S3 bucket policy (skips if not configured) |
| 6c | `delete-secrets-manager.yml` | Secret + local info file (skips if not configured) |
| 7 | Inline cleanup | Remaining local info files |

**Safety prompts:**
1. You must type the `app_name` to confirm the full teardown
2. S3 deletion asks separately — type `YES` to delete, or anything else to skip and preserve data

After completion, run the [verification checks](#verify-everything-is-gone) below.

---

## Step-by-Step Teardown

**Delete resources one at a time with verification after each step.**

Each step shows two options:
- **Playbook** — Automated, handles edge cases
- **CLI** — Manual AWS commands, educational

---

### Step 1: Terminate EC2 Instance

**Must be done first.** The security group and IAM role cannot be deleted while an instance is using them.

#### Option A: Playbook

```bash
cd deployment
ansible-playbook playbooks/terminate-ec2-instance.yml --vault-password-file ~/.vault_pass
```

The playbook will:
- Find the instance by `Name` tag
- Disable termination protection if enabled
- Terminate the instance and wait for completion
- Remove local instance info files from `instances/`

#### Option B: CLI

```bash
# Find instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}" \
              "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
echo "Instance: $INSTANCE_ID"

# Disable termination protection (if enabled)
aws ec2 modify-instance-attribute \
    --instance-id $INSTANCE_ID \
    --no-disable-api-termination

# Terminate and wait
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
echo "Waiting for termination..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
echo "✓ EC2 instance terminated"
```

#### Verify

```bash
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}" \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}'
# Should show "terminated" or empty
```

---

### Step 2: Delete SSH Key Pair

#### Option A: Playbook

```bash
ansible-playbook playbooks/delete-ssh-key.yml --vault-password-file ~/.vault_pass
```

#### Option B: CLI

```bash
aws ec2 delete-key-pair --key-name ${app_name}-key
rm -f ~/.ssh/${app_name}-key.pem
echo "✓ SSH key pair deleted"
```

#### Verify

```bash
aws ec2 describe-key-pairs --key-names ${app_name}-key 2>&1
# Should return: "The key pair does not exist"

ls ~/.ssh/${app_name}-key.pem 2>&1
# Should return: "No such file or directory"
```

---

### Step 3: Delete Security Group

> **Prerequisite:** EC2 instance must be terminated first (Step 1).
> If deletion fails with "DependencyViolation", wait 1-2 minutes and retry.

#### Option A: Playbook

```bash
ansible-playbook playbooks/delete-security-group.yml --vault-password-file ~/.vault_pass
```

The playbook retries 3 times with a 10-second delay if the instance dependency hasn't fully cleared.

#### Option B: CLI

```bash
# Wait for instance dependencies to clear
sleep 15

aws ec2 delete-security-group --group-name ${app_name}-sg
echo "✓ Security group deleted"
```

#### Verify

```bash
aws ec2 describe-security-groups --group-names ${app_name}-sg 2>&1
# Should return: "The security group does not exist"
```

---

### Step 4: Delete IAM Role + Policies

This is the most complex step. An IAM role **cannot be deleted** until:
- All inline policies are removed
- All managed policies are detached
- All instance profiles are detached and deleted

The `delete-iam-role.yml` playbook handles all of this automatically, including stale instance profiles from older deployments.

#### Option A: Playbook (recommended)

```bash
ansible-playbook playbooks/delete-iam-role.yml --vault-password-file ~/.vault_pass
```

**What it removes (in order):**

| Step | Resource | Name |
|------|----------|------|
| 1/4 | Inline policies | `{app_name}-s3-access`, `-secrets-access`, `-cloudwatch-access` |
| 2/4 | Managed policy | `AmazonSSMManagedInstanceCore` |
| 3/4 | Instance profiles | `{app_name}-instance-profile` + any stale profiles discovered via API |
| 4/4 | IAM role | `{app_name}-ec2-role` |

#### Option B: CLI

**4a. Find all instance profiles attached to the role:**
```bash
aws iam list-instance-profiles-for-role \
    --role-name ${app_name}-ec2-role \
    --query 'InstanceProfiles[].InstanceProfileName' \
    --output text
```

**4b. Remove the role from each profile and delete it:**
```bash
# For EACH profile name shown above, run these two commands.
# Replace PROFILE_NAME with each actual name.

aws iam remove-role-from-instance-profile \
    --instance-profile-name PROFILE_NAME \
    --role-name ${app_name}-ec2-role
aws iam delete-instance-profile \
    --instance-profile-name PROFILE_NAME

# Common profile names to check:
#   ${app_name}-instance-profile   (current naming)
#   ${app_name}-ec2-role           (old naming from earlier deployments)
```

**4c. Delete inline policies:**
```bash
aws iam delete-role-policy \
    --role-name ${app_name}-ec2-role \
    --policy-name ${app_name}-s3-access
aws iam delete-role-policy \
    --role-name ${app_name}-ec2-role \
    --policy-name ${app_name}-secrets-access
aws iam delete-role-policy \
    --role-name ${app_name}-ec2-role \
    --policy-name ${app_name}-cloudwatch-access
```

**4d. Detach managed policies:**
```bash
aws iam detach-role-policy \
    --role-name ${app_name}-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

**4e. Verify the role is clean, then delete it:**
```bash
# Both should return empty lists
aws iam list-role-policies --role-name ${app_name}-ec2-role
aws iam list-attached-role-policies --role-name ${app_name}-ec2-role
aws iam list-instance-profiles-for-role --role-name ${app_name}-ec2-role

# Delete role (only works when fully clean)
aws iam delete-role --role-name ${app_name}-ec2-role
echo "✓ IAM role and policies deleted"
```

#### Verify

```bash
aws iam get-role --role-name ${app_name}-ec2-role 2>&1
# Should return: "NoSuchEntity"
```

---

### Step 5: Delete S3 Bucket

> ⚠️ **ALL DATA WILL BE PERMANENTLY LOST.** Back up first.
>
> The bucket name comes from `s3_bucket_name` in your vault, not from `app_name`.
> Check it: `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass | grep s3_bucket`

#### Option A: Playbook

```bash
ansible-playbook playbooks/delete-s3-bucket.yml --vault-password-file ~/.vault_pass
```

The playbook will:
1. Prompt you to type `YES` to confirm (type anything else to skip)
2. Empty all objects
3. Delete all object versions (versioned buckets)
4. Delete all delete markers
5. Delete the bucket

#### Option B: CLI

```bash
# Set your bucket name (must match s3_bucket_name)
S3_BUCKET="your-bucket-name-here"  # ⚠️ Change to YOUR vault value

# Empty all objects
aws s3 rm s3://$S3_BUCKET --recursive

# Delete all object versions (versioned buckets)
aws s3api list-object-versions --bucket $S3_BUCKET \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json | \
    python3 -c "
import json, sys, subprocess
versions = json.load(sys.stdin)
if versions:
    for v in versions:
        subprocess.run(['aws', 's3api', 'delete-object',
            '--bucket', '$S3_BUCKET',
            '--key', v['Key'], '--version-id', v['VersionId']], check=False)
"

# Delete all delete markers
aws s3api list-object-versions --bucket $S3_BUCKET \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json | \
    python3 -c "
import json, sys, subprocess
markers = json.load(sys.stdin)
if markers:
    for m in markers:
        subprocess.run(['aws', 's3api', 'delete-object',
            '--bucket', '$S3_BUCKET',
            '--key', m['Key'], '--version-id', m['VersionId']], check=False)
"

# Delete bucket
aws s3api delete-bucket --bucket $S3_BUCKET
echo "✓ S3 bucket deleted"
```

#### Verify

```bash
aws s3api head-bucket --bucket $S3_BUCKET 2>&1
# Should return: "Not Found" or "NoSuchBucket"
```

---

### Step 6: Delete Secrets Manager Secret

**Optional.** Only needed if you used `setup-secrets-manager.yml` during deployment.

#### Option A: Playbook

The `decommission.yml` playbook handles this automatically. No standalone playbook exists for Secrets Manager — it's a single CLI call.

#### Option B: CLI

```bash
aws secretsmanager delete-secret \
    --secret-id ${app_name}/production \
    --force-delete-without-recovery
echo "✓ Secrets Manager secret deleted"
```

#### Verify

```bash
aws secretsmanager describe-secret --secret-id ${app_name}/production 2>&1
# Should return: "ResourceNotFoundException"
```

---

### Step 7: Delete WAF (optional)

**Only if you ran `setup-waf.yml` during deployment.**

#### Option A: Playbook

```bash
ansible-playbook playbooks/delete-waf.yml --vault-password-file ~/.vault_pass
```

The playbook will:
1. Find the Web ACL by name
2. Disassociate from any ALBs
3. Delete the Web ACL
4. Delete the IP set
5. Remove local `waf-info.txt`

#### Option B: CLI

```bash
# Find Web ACL ID and lock token
aws wafv2 list-web-acls --scope REGIONAL --region ${aws_region} \
    --query "WebACLs[?Name=='${app_name}-web-acl']"

# Delete Web ACL (replace ID and LOCK_TOKEN from above)
aws wafv2 delete-web-acl \
    --name ${app_name}-web-acl \
    --scope REGIONAL \
    --id YOUR_WEB_ACL_ID \
    --lock-token YOUR_LOCK_TOKEN \
    --region ${aws_region}

# Find and delete IP set
aws wafv2 list-ip-sets --scope REGIONAL --region ${aws_region} \
    --query "IPSets[?Name=='${app_name}-rate-limit-ips']"

aws wafv2 delete-ip-set \
    --name ${app_name}-rate-limit-ips \
    --scope REGIONAL \
    --id YOUR_IPSET_ID \
    --lock-token YOUR_LOCK_TOKEN \
    --region ${aws_region}

echo "✓ WAF deleted"
```

---

### Step 8: Delete CloudFront (optional)

**Only if `enable_cloudfront: true` in your vault.yml.**

> **Note:** CloudFront distributions must be **disabled** before they can be deleted.
> Disabling takes **10-15 minutes**. The playbook handles this automatically.

#### Option A: Playbook (recommended)

```bash
ansible-playbook playbooks/delete-cloudfront.yml --vault-password-file ~/.vault_pass
```

The playbook will:
1. Find the distribution by comment tag
2. Disable it and wait for propagation (~15 min)
3. Delete the distribution
4. Delete the Origin Access Identity
5. Remove the S3 bucket policy for CloudFront
6. Remove local `cloudfront-info.txt`

#### Option B: CLI

```bash
# Find distribution ID
DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Comment=='CDN for ${app_display_name}'].Id" \
    --output text)
echo "Distribution: $DIST_ID"

# Get config and ETag
aws cloudfront get-distribution-config --id $DIST_ID > /tmp/cf-config.json
ETAG=$(python3 -c "import json; print(json.load(open('/tmp/cf-config.json'))['ETag'])")

# Disable distribution (edit config to set Enabled=false)
python3 -c "
import json
data = json.load(open('/tmp/cf-config.json'))
data['DistributionConfig']['Enabled'] = False
json.dump(data['DistributionConfig'], open('/tmp/cf-disable.json', 'w'))
"
aws cloudfront update-distribution --id $DIST_ID \
    --distribution-config file:///tmp/cf-disable.json --if-match $ETAG

# Wait for disable to propagate (10-15 minutes)
echo "Waiting for distribution to disable..."
aws cloudfront wait distribution-deployed --id $DIST_ID

# Get new ETag after disable
NEW_ETAG=$(aws cloudfront get-distribution-config --id $DIST_ID \
    --query 'ETag' --output text)

# Delete distribution
aws cloudfront delete-distribution --id $DIST_ID --if-match $NEW_ETAG

# Delete OAI
aws cloudfront list-cloud-front-origin-access-identities \
    --query "CloudFrontOriginAccessIdentityList.Items[?contains(Comment, '${app_name}')].Id" \
    --output text

# For each OAI ID found:
# OAI_ETAG=$(aws cloudfront get-cloud-front-origin-access-identity --id OAI_ID --query 'ETag' --output text)
# aws cloudfront delete-cloud-front-origin-access-identity --id OAI_ID --if-match $OAI_ETAG

# Remove S3 bucket policy
aws s3api delete-bucket-policy --bucket ${s3_bucket_name}

echo "✓ CloudFront deleted"
```

---

## Verify Everything Is Gone

Run all checks at once after teardown:

```bash
cd deployment
source scripts/load-vars.sh

echo "=== EC2 Instance ==="
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${app_name}" \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' \
    --output table

echo "=== SSH Key Pair ==="
aws ec2 describe-key-pairs --key-names ${app_name}-key 2>&1 | head -3

echo "=== Security Group ==="
aws ec2 describe-security-groups --group-names ${app_name}-sg 2>&1 | head -3

echo "=== IAM Role ==="
aws iam get-role --role-name ${app_name}-ec2-role 2>&1 | head -3

echo "=== S3 Bucket ==="
aws s3api list-buckets --query 'Buckets[].Name' --output text | tr '\t' '\n' | grep ${app_name} || echo "No matching buckets"

echo "=== Secrets Manager ==="
aws secretsmanager describe-secret --secret-id ${app_name}/production 2>&1 | head -3

echo "=== WAF ==="
aws wafv2 list-web-acls --scope REGIONAL --region ${aws_region} \
    --query "WebACLs[?Name=='${app_name}-web-acl'].Name" --output text 2>&1
# Should be empty

echo "=== CloudFront ==="
aws cloudfront list-distributions \
    --query "DistributionList.Items[?Comment=='CDN for ${app_display_name}'].Id" \
    --output text 2>&1
# Should be empty
```

**Expected:** Every check should return "not found", "does not exist", or "terminated".

---

## Single Resource Rollback

Need to fix just one resource? Delete it and recreate it without tearing down everything:

```bash
cd deployment

# Example: rollback and recreate the security group
ansible-playbook playbooks/delete-security-group.yml --vault-password-file ~/.vault_pass
ansible-playbook playbooks/create-security-group.yml --vault-password-file ~/.vault_pass
```

### Playbook Reference

| Create | Delete | Resource |
|--------|--------|----------|
| `create-iam-user.yml` | `delete-iam-user.yml` | IAM deployer user + policies + access keys |
| `create-s3-bucket.yml` | `delete-s3-bucket.yml` | S3 Bucket |
| `create-iam-role.yml` | `delete-iam-role.yml` | IAM Role + all policies + all instance profiles |
| `create-security-group.yml` | `delete-security-group.yml` | Security Group |
| `create-ssh-key.yml` | `delete-ssh-key.yml` | SSH Key Pair (AWS + local file) |
| `launch-ec2-instance.yml` | `terminate-ec2-instance.yml` | EC2 Instance |
| `setup-waf.yml` | `delete-waf.yml` | WAF Web ACL + IP set |
| `setup-cloudfront.yml` | `delete-cloudfront.yml` | CloudFront distribution + OAI |
| `setup-secrets-manager.yml` | `delete-secrets-manager.yml` | Secrets Manager secret |

> **Dependency order matters when deleting:**
> - Terminate EC2 before deleting Security Group or IAM Role
> - Delete all policies and instance profiles before deleting IAM Role

---

## Troubleshooting

### "Cannot delete entity, must remove roles from instance profile first"

The IAM role still has instance profiles attached. Check what's attached:

```bash
aws iam list-instance-profiles-for-role --role-name ${app_name}-ec2-role
```

Then remove each one (see [Step 4b](#option-b-cli-3)).

This commonly happens when an earlier deployment used a different instance profile naming convention.

### "DependencyViolation" when deleting Security Group

The EC2 instance hasn't fully terminated yet. Wait 1-2 minutes and retry:

```bash
sleep 60
aws ec2 delete-security-group --group-name ${app_name}-sg
```

### S3 bucket won't delete — "BucketNotEmpty"

Versioned buckets keep old object versions even after `aws s3 rm --recursive`. You must also delete versions and delete markers. See [Step 5 CLI](#option-b-cli-4) for the full procedure.

### "NoSuchEntity" errors during teardown

This is normal — it means the resource was already deleted. The playbooks use `failed_when: false` to handle this gracefully.

---

## See also

- [Chapter 5: Operations — Server Decommissioning](OPERATIONS.md#server-decommissioning) — pre-decommission backup checklist
- [Chapter 2: Quick Start](QUICKSTART.md) — redeploy from scratch
- [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) — step-by-step redeploy
- [Infrastructure Reference](INFRASTRUCTURE.md) — what each resource does

