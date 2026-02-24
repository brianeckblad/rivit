# AWS Secrets Manager Setup with Ansible

**Date:** February 24, 2026  
**Version:** 2.0 - Updated with AWS Modules

---

## Overview

The `setup-secrets-manager.yml` playbook configures AWS Secrets Manager to store application secrets extracted from your Ansible Vault.

**Key Features:**
- ✅ Extracts secrets from encrypted Ansible Vault
- ✅ Creates AWS Secrets Manager secret
- ✅ Uses native Ansible AWS modules (no shell commands)
- ✅ Automatic rotation support
- ✅ Resource tagging for tracking

---

## What It Does

### Step 1: Extract Vault Variables
```yaml
- name: Extract secrets from vault variables
  set_fact:
    vault_secrets: "{{ vault_secrets | default({}) | combine({item.replace('vault_', ''): vars[item]}) }}"
  loop: "{{ query('varnames', '^vault_') }}"
  when: item is not match('_new$')
```

**Details:**
- Uses `query('varnames', '^vault_')` to get all vault variables (modern, non-deprecated approach)
- Filters out `_new` suffixed variables (used for rotation)
- Stores in dictionary format for JSON serialization

### Step 2: Create AWS Secrets Manager Secret
```yaml
- name: Create Secrets Manager secret
  amazon.aws.secretsmanager_secret:
    name: "{{ app_name }}/production"
    description: "Secrets for {{ app_display_name }} production environment"
    secret: "{}"
    region: "{{ aws_region }}"
    state: present
```

**Details:**
- Uses `amazon.aws.secretsmanager_secret` module (native Ansible)
- Creates secret with app_name/production naming convention
- Initial secret is empty JSON (will be populated in next step)
- No shell commands = no sudo issues

### Step 3: Get Secret Information
```yaml
- name: Get secret ARN
  amazon.aws.secretsmanager_secret:
    name: "{{ app_name }}/production"
    region: "{{ aws_region }}"
  register: secret_info
```

**Details:**
- Queries the secret to get full information
- Stores ARN, metadata, and other details in `secret_info`
- Used for output and reference

### Step 4: Update Secret with Vault Contents
```yaml
- name: Update secret with vault contents
  amazon.aws.secretsmanager_secret:
    name: "{{ app_name }}/production"
    secret: "{{ vault_secrets | to_json }}"
    region: "{{ aws_region }}"
```

**Details:**
- Converts extracted vault secrets to JSON
- Updates the secret with actual values
- All secrets now available in Secrets Manager

### Step 5: Configure Automatic Rotation (Optional)
```bash
aws secretsmanager rotate-secret \
  --secret-id {{ app_name }}/production \
  --rotation-rules AutomaticallyAfterDays=30 \
  --region {{ aws_region }}
```

**Details:**
- Enables 30-day automatic rotation
- Uses shell command (no module available for this)
- Optional - can be skipped if not needed

### Step 6: Tag Resources
```bash
aws secretsmanager tag-resource \
  --secret-id {{ app_name }}/production \
  --tags Key=Application,Value={{ app_name }} Key=Environment,Value=production Key=ManagedBy,Value=Ansible
```

**Details:**
- Tags secret for tracking and cost allocation
- Uses shell command for complex tagging
- Helps identify automated resources

---

## Execution

### Run the Playbook

```bash
cd deployment

# Load variables
source scripts/load-vars.sh

# Run playbook
ansible-playbook playbooks/setup-secrets-manager.yml \
  --vault-password-file ~/.vault_pass
```

### Expected Output

```
PLAY [Setup AWS Secrets Manager]

TASK [Extract secrets from vault variables]
ok: [localhost] => (item=vault_git_repo)
ok: [localhost] => (item=vault_aws_region)
...

TASK [Create Secrets Manager secret]
changed: [localhost]

TASK [Get secret ARN]
ok: [localhost]

TASK [Update secret with vault contents]
changed: [localhost]

TASK [Enable automatic rotation (optional)]
changed: [localhost]

TASK [Tag secret]
changed: [localhost]

TASK [Display Secrets Manager information]
msg:
  - "✓ AWS Secrets Manager configured"
  - "Secret Name: rampe/production"
  - "Secret ARN: arn:aws:secretsmanager:us-east-2:123456789012:secret:rampe/production-xxxxx"
  - "Region: us-east-2"
  - ""
  - "Secrets stored: 12"
  - "Keys: [git_repo, ebay_api_key, ...]"
```

---

## Technical Details

### Why AWS Modules Instead of Shell Commands?

**Before (Shell Commands):**
```yaml
command: aws secretsmanager create-secret --name {{ app_name }}/production ...
```

**Problems:**
- ❌ Quote escaping complexity
- ❌ Shell command parsing issues
- ❌ Sudo password prompts
- ❌ Harder to handle errors

**After (AWS Modules):**
```yaml
amazon.aws.secretsmanager_secret:
  name: "{{ app_name }}/production"
  secret: "{}"
  region: "{{ aws_region }}"
```

**Benefits:**
- ✅ Native Ansible module
- ✅ No shell interpretation
- ✅ No sudo issues
- ✅ Better error handling
- ✅ More portable

### Why query('varnames') Instead of lookup('dict', vars)?

**Before (Deprecated):**
```yaml
loop: "{{ lookup('dict', vars) }}"  # Deprecated warning in Ansible 2.24+
```

**After (Current Best Practice):**
```yaml
loop: "{{ query('varnames', '^vault_') }}"  # Future-proof
```

**Benefits:**
- ✅ No deprecation warnings
- ✅ Compatible with Ansible 2.24+
- ✅ More efficient filtering
- ✅ Cleaner syntax

---

## Security Considerations

### IAM Permissions Required

The EC2 instance needs these permissions (set up by `create-iam-role.yml`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:{app_name}/*"
    }
  ]
}
```

### Secret Storage

- ✅ Secrets encrypted at rest (AES-256)
- ✅ Secrets encrypted in transit (TLS)
- ✅ Access via IAM role only
- ✅ No secrets on disk on EC2
- ✅ Audit trail in CloudTrail

---

## Accessing Secrets from Application

### Python Example

```python
import boto3
import json

client = boto3.client('secretsmanager', region_name='us-east-2')

response = client.get_secret_value(SecretId='rampe/production')
secrets = json.loads(response['SecretString'])

# Now use secrets
git_repo = secrets['git_repo']
ebay_api_key = secrets['ebay_api_key']
```

### CLI Example

```bash
aws secretsmanager get-secret-value \
  --secret-id rampe/production \
  --query SecretString \
  --output text | jq .ebay_api_key
```

---

## Troubleshooting

### Secret Not Created

```bash
# Check if secret exists
aws secretsmanager list-secrets --region us-east-2 | grep rampe/production

# If not found, check playbook output for errors
ansible-playbook playbooks/setup-secrets-manager.yml \
  --vault-password-file ~/.vault_pass -vv
```

### Can't Access Secret from Application

```bash
# 1. Verify IAM role has access
aws iam get-role --role-name rampe-ec2-role

# 2. Verify EC2 instance has the role
aws ec2 describe-instances --filters "Name=tag:Name,Values=rampe-server" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# 3. Test from application server
aws secretsmanager get-secret-value --secret-id rampe/production
```

### Rotation Issues

```bash
# Check rotation history
aws secretsmanager describe-secret --secret-id rampe/production \
  --query 'RotationDetails'

# Manually rotate (if auto-rotation fails)
aws secretsmanager rotate-secret --secret-id rampe/production \
  --rotation-rules AutomaticallyAfterDays=30
```

---

## Integration with Deployment

### Part of Initial Setup

The `setup-secrets-manager.yml` playbook is typically run:

1. **After:** Creating IAM role (`create-iam-role.yml`)
2. **Before:** Deploying application code
3. **As Part Of:** Initial infrastructure setup

### Running in Automated Deployment

In `provision-infrastructure.yml`:

```yaml
- name: Setup AWS Secrets Manager
  import_playbook: setup-secrets-manager.yml
```

### Running Manually

```bash
cd deployment
source scripts/load-vars.sh
ansible-playbook playbooks/setup-secrets-manager.yml \
  --vault-password-file ~/.vault_pass
```

---

## Configuration Reference

### Variables Used

| Variable | Source | Example | Purpose |
|----------|--------|---------|---------|
| `app_name` | all.yml | rampe | Secret naming |
| `app_display_name` | all.yml | Rampe Application | Secret description |
| `aws_region` | all.yml | us-east-2 | AWS region |
| `vault_*` variables | vault.yml (encrypted) | vault_git_repo | Secret values |

### Output Files

```
deployment/secrets-manager-info.txt
```

Contains:
- Secret name and ARN
- Number of secrets stored
- List of secret keys
- Access examples (Python, CLI)
- IAM role information

---

## Next Steps

After running this playbook:

1. ✅ Verify secret was created: `aws secretsmanager list-secrets`
2. ✅ Check info file: `cat deployment/secrets-manager-info.txt`
3. ✅ Deploy application code
4. ✅ Application will fetch secrets from Secrets Manager

---

## Related Documentation

- [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md) - Full secret management strategy
- [VAULT_PASSWORD_USAGE.md](VAULT_PASSWORD_USAGE.md) - Vault password setup
- [OPERATIONS.md](OPERATIONS.md) - Operational tasks including secret rotation
- [create-iam-role.yml](../playbooks/create-iam-role.yml) - IAM permissions setup


