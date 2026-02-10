#!/bin/bash
#
# IAM Role Setup for EC2 Instance
# Creates IAM role with policies for S3, Secrets Manager, and SSM access
#
# Usage: ./iam-role-setup.sh <role-name> <s3-bucket> <region>
#

set -e

ROLE_NAME="${1:-app-item-listing-tool-ec2-role}"
S3_BUCKET="${2:-}"
AWS_REGION="${3:-us-east-1}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}▶ Setting up IAM role: $ROLE_NAME${NC}"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

#############################################
# Step 1: Create IAM Role
#############################################

echo -e "${BLUE}▶ Creating IAM role...${NC}"

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Role already exists: $ROLE_NAME${NC}"
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "EC2 role for app-item-listing-tool with S3, Secrets Manager, and SSM access"
    echo -e "${GREEN}✓ IAM role created: $ROLE_NAME${NC}"
fi

#############################################
# Step 2: Attach Managed Policies
#############################################

echo -e "${BLUE}▶ Attaching managed policies...${NC}"

# SSM Managed Instance Core (for SSM Session Manager)
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" \
    2>/dev/null || echo -e "${YELLOW}⚠ SSM policy already attached${NC}"

echo -e "${GREEN}✓ SSM Session Manager policy attached${NC}"

#############################################
# Step 3: Create Custom S3 Policy (Least Privilege)
#############################################

echo -e "${BLUE}▶ Creating S3 access policy...${NC}"

if [ -n "$S3_BUCKET" ]; then
    S3_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}"
    },
    {
      "Sid": "ObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    }
  ]
}
EOF
)
else
    # Fallback to full S3 access if bucket not specified
    S3_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:PutObjectAcl"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)
fi

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "S3Access" \
    --policy-document "$S3_POLICY"

echo -e "${GREEN}✓ S3 access policy attached${NC}"

#############################################
# Step 4: Create Secrets Manager Policy
#############################################

echo -e "${BLUE}▶ Creating Secrets Manager access policy...${NC}"

SECRETS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:app-item-listing-tool/*",
        "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:*/production-*"
      ]
    }
  ]
}
EOF
)

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "SecretsManagerAccess" \
    --policy-document "$SECRETS_POLICY"

echo -e "${GREEN}✓ Secrets Manager access policy attached${NC}"

#############################################
# Step 5: Create Instance Profile
#############################################

echo -e "${BLUE}▶ Creating instance profile...${NC}"

PROFILE_NAME="${ROLE_NAME}-profile"

if aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Instance profile already exists: $PROFILE_NAME${NC}"
else
    aws iam create-instance-profile \
        --instance-profile-name "$PROFILE_NAME"

    # Wait for instance profile to be ready
    sleep 2

    echo -e "${GREEN}✓ Instance profile created: $PROFILE_NAME${NC}"
fi

#############################################
# Step 6: Add Role to Instance Profile
#############################################

echo -e "${BLUE}▶ Adding role to instance profile...${NC}"

# Check if role is already in profile
if aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" \
    --query 'InstanceProfile.Roles[?RoleName==`'"$ROLE_NAME"'`]' \
    --output text | grep -q "$ROLE_NAME"; then
    echo -e "${YELLOW}⚠ Role already in instance profile${NC}"
else
    aws iam add-role-to-instance-profile \
        --instance-profile-name "$PROFILE_NAME" \
        --role-name "$ROLE_NAME"

    echo -e "${GREEN}✓ Role added to instance profile${NC}"
fi

echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}IAM Role Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo -e "${BLUE}Role Name:${NC} $ROLE_NAME"
echo -e "${BLUE}Instance Profile:${NC} $PROFILE_NAME"
echo
echo -e "${BLUE}Policies Attached:${NC}"
echo -e "  ✓ AmazonSSMManagedInstanceCore (SSM Session Manager)"
echo -e "  ✓ S3Access (S3 bucket access)"
echo -e "  ✓ SecretsManagerAccess (Secrets Manager read)"
echo
echo -e "${BLUE}ARN:${NC}"
echo -e "  arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo -e "  arn:aws:iam::${ACCOUNT_ID}:instance-profile/${PROFILE_NAME}"
echo
echo -e "${YELLOW}To attach this to an EC2 instance:${NC}"
echo -e "  aws ec2 associate-iam-instance-profile \\"
echo -e "    --instance-id i-xxxxxxxxxxxxx \\"
echo -e "    --iam-instance-profile Name=$PROFILE_NAME"
echo
echo -e "${YELLOW}To launch new instance with this role:${NC}"
echo -e "  aws ec2 run-instances \\"
echo -e "    --iam-instance-profile Name=$PROFILE_NAME \\"
echo -e "    ... other parameters ..."
echo

# Export for use by other scripts
export IAM_INSTANCE_PROFILE="$PROFILE_NAME"
export IAM_ROLE_NAME="$ROLE_NAME"

# Save to file for sourcing
cat > "/tmp/iam-role-info.sh" <<EOF
export IAM_INSTANCE_PROFILE="$PROFILE_NAME"
export IAM_ROLE_NAME="$ROLE_NAME"
export IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
EOF

echo -e "${GREEN}✓ Role info saved to: /tmp/iam-role-info.sh${NC}"
echo -e "${BLUE}  Source it with: source /tmp/iam-role-info.sh${NC}"
echo

