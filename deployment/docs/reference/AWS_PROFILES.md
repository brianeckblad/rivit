# AWS CLI Multiple Profiles Guide

**Managing Multiple AWS Accounts and Regions**

---

## Overview

AWS CLI profiles allow you to:
- Manage multiple AWS accounts from one machine
- Switch between different regions easily
- Separate development, staging, and production credentials
- Work with multiple projects without reconfiguring

---

## Quick Start

### Single Profile (Default)
```bash
# This is what you've been using
aws configure
# Creates [default] profile
```

### Multiple Profiles
```bash
# Create a named profile
aws configure --profile myapp-production
aws configure --profile myapp-staging
aws configure --profile otherproject-dev

# Use a specific profile
aws s3 ls --profile myapp-production
```

---

## Setting Up Multiple Profiles

### Method 1: Interactive Configuration (Recommended)

```bash
# Configure production account
aws configure --profile myapp-production
AWS Access Key ID [None]: AKIA...           # Production IAM user
AWS Secret Access Key [None]: secret...     # Production secret
Default region name [None]: us-east-2       # Production region
Default output format [None]: json

# Configure staging account
aws configure --profile myapp-staging
AWS Access Key ID [None]: AKIA...           # Staging IAM user
AWS Secret Access Key [None]: secret...     # Staging secret
Default region name [None]: us-west-2       # Staging region
Default output format [None]: json

# Configure another project
aws configure --profile otherproject-dev
AWS Access Key ID [None]: AKIA...           # Different account
AWS Secret Access Key [None]: secret...
Default region name [None]: eu-west-1       # Different region
Default output format [None]: json
```

### Method 2: Manual File Editing

**Credentials file:** `~/.aws/credentials`
```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = secret...

[myapp-production]
aws_access_key_id = AKIA...
aws_secret_access_key = secret...

[myapp-staging]
aws_access_key_id = AKIA...
aws_secret_access_key = secret...

[otherproject-dev]
aws_access_key_id = AKIA...
aws_secret_access_key = secret...
```

**Config file:** `~/.aws/config`
```ini
[default]
region = us-east-2
output = json

[profile myapp-production]
region = us-east-2
output = json

[profile myapp-staging]
region = us-west-2
output = json

[profile otherproject-dev]
region = eu-west-1
output = json
```

**Note:** In config file, profile names have `profile` prefix except `[default]`.

---

## Using Profiles

### Command Line

```bash
# Use specific profile for one command
aws s3 ls --profile myapp-production

# Deploy to production
aws s3 mb s3://prod-bucket --profile myapp-production

# Deploy to staging
aws s3 mb s3://staging-bucket --profile myapp-staging
```

### Environment Variable (Temporary)

```bash
# Set profile for current terminal session
export AWS_PROFILE=myapp-production

# Now all aws commands use this profile
aws s3 ls                           # Uses myapp-production
aws ec2 describe-instances          # Uses myapp-production

# Switch to different profile
export AWS_PROFILE=myapp-staging
aws s3 ls                           # Now uses myapp-staging

# Unset to go back to default
unset AWS_PROFILE
```

### Shell Configuration (Permanent)

Add to `~/.bashrc` or `~/.zshrc`:
```bash
# Set default profile for this machine
export AWS_PROFILE=myapp-production

# Or create aliases
alias aws-prod='export AWS_PROFILE=myapp-production'
alias aws-staging='export AWS_PROFILE=myapp-staging'
alias aws-dev='export AWS_PROFILE=myapp-development'

# Usage:
# aws-prod
# aws s3 ls  # Uses production
```

---

## Deployment Scripts with Profiles

### Option 1: Environment Variable (Recommended)

```bash
# Set profile before running scripts
export AWS_PROFILE=myapp-production
cd deployment
./scripts/infra-complete-setup.sh

# Or one-liner
AWS_PROFILE=myapp-production ./scripts/infra-complete-setup.sh
```

### Option 2: Pass to Scripts

Scripts can detect `AWS_PROFILE` environment variable automatically:

```bash
# Production deployment
AWS_PROFILE=myapp-production ansible-playbook -i inventories playbooks/setup.yml

# Staging deployment
AWS_PROFILE=myapp-staging ansible-playbook -i inventories/staging playbooks/setup.yml
```

### Option 3: Hardcode in Inventory (Advanced)

**File:** `deployment/inventories/hosts`
```ini
[production]
your-server-ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prod-key.pem

[production:vars]
ansible_python_interpreter=/usr/bin/python3
aws_profile=myapp-production
```

Then in playbooks, use: `--profile {{ aws_profile }}`

---

## Verifying Profiles

### List All Profiles

```bash
# View configured profiles
cat ~/.aws/credentials | grep "\[" | tr -d '[]'

# Or
aws configure list-profiles
```

### Check Current Profile

```bash
# See which profile is active
echo $AWS_PROFILE

# If empty, using [default]

# Verify credentials
aws sts get-caller-identity
# Shows: Account ID and user ARN for current profile
```

### Test Each Profile

```bash
# Test production profile
aws sts get-caller-identity --profile myapp-production
# Should show production account

# Test staging profile
aws sts get-caller-identity --profile myapp-staging
# Should show staging account (different Account ID)
```

---

## Common Patterns

### Pattern 1: Separate Accounts per Environment

```ini
# ~/.aws/credentials
[myapp-dev]
aws_access_key_id = AKIA...      # Dev account
aws_secret_access_key = ...

[myapp-staging]
aws_access_key_id = AKIA...      # Staging account (different)
aws_secret_access_key = ...

[myapp-production]
aws_access_key_id = AKIA...      # Production account (different)
aws_secret_access_key = ...
```

**Benefits:**
- Complete isolation between environments
- Separate billing per environment
- Security: prod credentials never touch dev

### Pattern 2: Same Account, Different Regions

```ini
# ~/.aws/config
[profile myapp-us-east]
region = us-east-2
aws_access_key_id = AKIA...

[profile myapp-us-west]
region = us-west-2
aws_access_key_id = AKIA...      # Same account, different region

[profile myapp-europe]
region = eu-west-1
aws_access_key_id = AKIA...      # Same account, different region
```

**Benefits:**
- Multi-region deployments
- Disaster recovery in different region
- Geographic distribution

### Pattern 3: Multiple Projects

```ini
[project1-prod]
aws_access_key_id = AKIA...

[project2-prod]
aws_access_key_id = AKIA...      # Completely different project

[personal-dev]
aws_access_key_id = AKIA...      # Personal AWS account
```

---

## Security Best Practices

### 1. Never Use Root Account Credentials

```bash
# DON'T use root account access keys
# DO create IAM users with limited permissions
```

### 2. Use Different IAM Users per Environment

```bash
# Production IAM user: myapp-prod-deployer (limited to prod resources)
# Staging IAM user: myapp-staging-deployer (limited to staging)
```

### 3. Rotate Credentials Regularly

```bash
# Every 90 days, create new access keys
aws configure --profile myapp-production  # Enter new keys
# Then delete old keys in AWS Console
```

### 4. Protect Credentials Files

```bash
# Ensure proper permissions
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# Never commit to git
echo ".aws" >> ~/.gitignore
```

---

## Troubleshooting

### Wrong Account Being Used

```bash
# Check which profile is active
echo $AWS_PROFILE
aws sts get-caller-identity

# If wrong, set correct profile
export AWS_PROFILE=myapp-production
aws sts get-caller-identity  # Verify
```

### Profile Not Found

```bash
# Error: could not be found in the config file
# Solution: Check profile name exists
cat ~/.aws/credentials | grep myapp

# Create if missing
aws configure --profile myapp-production
```

### Credentials Expired

```bash
# Error: ExpiredToken or InvalidClientTokenId
# Solution: Get new access keys from AWS Console
# IAM → Users → [your-user] → Security credentials → Create access key
# Then:
aws configure --profile myapp-production
# Enter new credentials
```

### Region Mismatch

```bash
# Resource not found? Check region
aws configure get region --profile myapp-production

# Change region
aws configure set region us-west-2 --profile myapp-production
```

---

## Integration with Deployment

### For This Project

#### Step 1: Configure Profiles

```bash
# Production environment
aws configure --profile myapp-production
# Enter production account credentials
# Region: us-east-2

# Staging environment (optional)
aws configure --profile myapp-staging
# Enter staging account credentials
# Region: us-west-2
```

#### Step 2: Deploy with Profile

```bash
# Production deployment
export AWS_PROFILE=myapp-production
cd deployment
./scripts/infra-complete-setup.sh

# Or one command
AWS_PROFILE=myapp-production ./scripts/infra-complete-setup.sh
```

#### Step 3: Verify Resources

```bash
# Check S3 buckets in production
aws s3 ls --profile myapp-production

# Check EC2 instances in production
aws ec2 describe-instances --profile myapp-production
```

---

## Quick Reference

### Setup
```bash
# Create profile
aws configure --profile PROFILE_NAME

# View all profiles
aws configure list-profiles
```

### Usage
```bash
# Use for one command
aws COMMAND --profile PROFILE_NAME

# Set for session
export AWS_PROFILE=PROFILE_NAME

# Verify current profile
aws sts get-caller-identity
```

### Files
```
~/.aws/credentials    # Access keys (never commit!)
~/.aws/config         # Regions and settings
```

### Common Commands
```bash
# List S3 buckets
aws s3 ls --profile myapp-production

# Describe EC2 instances
aws ec2 describe-instances --profile myapp-production

# Get caller identity (who am I?)
aws sts get-caller-identity --profile myapp-production
```

---

## Example Workflow

### Scenario: Deploy to Multiple Environments

```bash
# 1. Configure profiles (one-time)
aws configure --profile myapp-dev
aws configure --profile myapp-production

# 2. Deploy to dev
export AWS_PROFILE=myapp-dev
cd deployment
./scripts/infra-complete-setup.sh
# Creates resources in dev account

# 3. Test in dev
aws s3 ls  # Lists dev buckets
aws ec2 describe-instances  # Lists dev instances

# 4. Deploy to production
export AWS_PROFILE=myapp-production
./scripts/infra-complete-setup.sh
# Creates resources in production account

# 5. Verify production
aws sts get-caller-identity
# Confirms you're in production account
```

---

## Summary

✅ **Profiles let you:**
- Manage multiple AWS accounts
- Switch between regions
- Separate environments
- Work on multiple projects

✅ **Setup:**
- `aws configure --profile NAME`
- Creates entries in `~/.aws/credentials` and `~/.aws/config`

✅ **Usage:**
- `--profile NAME` flag on commands
- `export AWS_PROFILE=NAME` for session
- Scripts inherit from environment

✅ **Best practices:**
- Different profiles per environment
- Never use root account
- Protect credentials files
- Rotate keys regularly

---

## Need Help?

- **Can't create profile?** Run `aws configure --profile myapp-production` again
- **Wrong account?** Check `echo $AWS_PROFILE` and `aws sts get-caller-identity`
- **Credentials not working?** Verify in AWS Console → IAM → Users
- **Deployment failed?** Set `AWS_PROFILE` before running scripts

