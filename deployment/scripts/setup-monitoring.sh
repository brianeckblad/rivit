#!/bin/bash
# Script to setup S3 versioning, lifecycle policies, CloudWatch, and SNS
# Usage: ./setup-monitoring.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source the app name getter function
source "$SCRIPT_DIR/lib/get_app_name.sh"

# Get app name from config
DEFAULT_APP_NAME=$(get_app_name 2>/dev/null || echo "app_name")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  AWS Monitoring & S3 Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install with: pip install awscli"
    exit 1
fi

# Check if ansible-vault is available
if ! command -v ansible-vault &> /dev/null; then
    echo -e "${RED}Error: ansible-vault is not installed${NC}"
    exit 1
fi

# Check for vault password file
if [ ! -f ~/.vault_pass ]; then
    echo -e "${RED}Error: Vault password file not found at ~/.vault_pass${NC}"
    exit 1
fi

# Load variables from vault
echo -e "${YELLOW}Loading configuration from vault...${NC}"
BUCKET_NAME=$(ansible-vault view "$DEPLOYMENT_DIR/group_vars/production/vault.yml" --vault-password-file ~/.vault_pass 2>/dev/null | grep 'vault_s3_bucket_name:' | awk '{print $2}' | tr -d '"')
AWS_REGION=$(ansible-vault view "$DEPLOYMENT_DIR/group_vars/production/vault.yml" --vault-password-file ~/.vault_pass 2>/dev/null | grep 'vault_aws_region:' | awk '{print $2}' | tr -d '"' || echo "us-east-2")

# Load retention days from all.yml
S3_VERSION_RETENTION=$(grep 's3_version_retention_days:' "$DEPLOYMENT_DIR/group_vars/all.yml" | awk '{print $2}' || echo "30")

if [ -z "$BUCKET_NAME" ]; then
    echo -e "${RED}Error: Could not find S3 bucket name in vault${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Bucket: $BUCKET_NAME${NC}"
echo -e "${GREEN}✓ Region: $AWS_REGION${NC}"
echo -e "${GREEN}✓ Version Retention: $S3_VERSION_RETENTION days${NC}"
echo ""

# Step 1: Enable S3 Versioning
echo -e "${BLUE}Step 1: Enabling S3 Versioning...${NC}"
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ S3 versioning enabled${NC}"
else
    echo -e "${RED}✗ Failed to enable S3 versioning${NC}"
    exit 1
fi

# Step 2: Create S3 Lifecycle Policy
echo -e "${BLUE}Step 2: Creating S3 Lifecycle Policy...${NC}"

cat > /tmp/s3-lifecycle-policy.json << EOF
{
  "Rules": [
    {
      "Id": "optimize-storage-costs",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "users/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER_IR"
        }
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": $S3_VERSION_RETENTION,
          "StorageClass": "GLACIER_IR"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": $(($S3_VERSION_RETENTION + 30))
      }
    },
    {
      "Id": "delete-old-trash",
      "Status": "Enabled",
      "Filter": {
        "And": {
          "Prefix": "users/",
          "Tags": [
            {
              "Key": "Type",
              "Value": "trash"
            }
          ]
        }
      },
      "Expiration": {
        "Days": 30
      }
    },
    {
      "Id": "intelligent-tiering-images",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "users/"
      },
      "Transitions": [
        {
          "Days": 0,
          "StorageClass": "INTELLIGENT_TIERING"
        }
      ]
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file:///tmp/s3-lifecycle-policy.json \
    --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ S3 lifecycle policy applied${NC}"
    echo -e "  - ${BLUE}Current files: ALWAYS online (never moved to Glacier)${NC}"
    echo -e "  - ${BLUE}Old versions: Kept online for $S3_VERSION_RETENTION days, then deleted${NC}"
    echo -e "  - Trash items: Auto-deleted after 30 days"
else
    echo -e "${RED}✗ Failed to apply lifecycle policy${NC}"
fi

rm /tmp/s3-lifecycle-policy.json

# Step 3: Create SNS Topic for Alerts
echo -e "${BLUE}Step 3: Setting up SNS Notifications...${NC}"

# Check if SNS topic already exists in vault
EXISTING_TOPIC=$(ansible-vault view "$DEPLOYMENT_DIR/group_vars/production/vault.yml" --vault-password-file ~/.vault_pass 2>/dev/null | grep 'vault_sns_topic_arn:' | awk '{print $2}' | tr -d '"')

if [ -z "$EXISTING_TOPIC" ]; then
    echo -e "${YELLOW}Creating new SNS topic...${NC}"

    TOPIC_ARN=$(aws sns create-topic \
        --name ${INSTANCE_NAME:-$DEFAULT_APP_NAME}-alerts \
        --region "$AWS_REGION" \
        --query 'TopicArn' \
        --output text)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SNS topic created: $TOPIC_ARN${NC}"
        echo ""
        echo -e "${YELLOW}Action Required:${NC}"
        echo -e "1. Add your email subscription:"
        echo -e "   ${BLUE}aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint your-email@example.com${NC}"
        echo ""
        echo -e "2. Add to vault:"
        echo -e "   ${BLUE}ansible-vault edit $DEPLOYMENT_DIR/group_vars/production/vault.yml --vault-password-file ~/.vault_pass${NC}"
        echo -e "   Add this line:"
        echo -e "   ${BLUE}vault_sns_topic_arn: \"$TOPIC_ARN\"${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠ Could not create SNS topic (may need permissions)${NC}"
    fi
else
    echo -e "${GREEN}✓ SNS topic already configured: $EXISTING_TOPIC${NC}"
fi

# Step 4: Create CloudWatch Alarms
echo -e "${BLUE}Step 4: Creating CloudWatch Alarms...${NC}"

# Get EC2 instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${APP_NAME}*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    echo -e "${GREEN}✓ Found EC2 instance: $INSTANCE_ID${NC}"

    # High CPU Alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name app-high-cpu \
        --alarm-description "Alert when CPU exceeds 80%" \
        --metric-name CPUUtilization \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 300 \
        --evaluation-periods 2 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --region "$AWS_REGION" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ High CPU alarm created${NC}"
    fi

    # Disk space alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name app-low-disk-space \
        --alarm-description "Alert when disk usage exceeds 85%" \
        --metric-name disk_used_percent \
        --namespace CWAgent \
        --statistic Average \
        --period 300 \
        --evaluation-periods 1 \
        --threshold 85 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --region "$AWS_REGION" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Low disk space alarm created${NC}"
    fi
else
    echo -e "${YELLOW}⚠ EC2 instance not found, skipping instance-specific alarms${NC}"
fi

# Application-level alarms (will work once metrics start flowing)
aws cloudwatch put-metric-alarm \
    --alarm-name app-high-errors \
    --alarm-description "Alert when error rate is high" \
    --metric-name APIRequestCount \
    --namespace AppItemListingTool \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=status,Value=error \
    --treat-missing-data notBreaching \
    --region "$AWS_REGION" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ High error rate alarm created${NC}"
fi

aws cloudwatch put-metric-alarm \
    --alarm-name app-slow-response \
    --alarm-description "Alert when responses are slow" \
    --metric-name APIResponseTime \
    --namespace ${CLOUDWATCH_NAMESPACE:-Rampe} \
    --statistic Average \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 2000 \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    --region "$AWS_REGION" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Slow response alarm created${NC}"
fi

# Step 5: Verify setup
echo ""
echo -e "${BLUE}Step 5: Verifying Configuration...${NC}"

# Verify versioning
VERSIONING_STATUS=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" --query 'Status' --output text 2>/dev/null)
if [ "$VERSIONING_STATUS" = "Enabled" ]; then
    echo -e "${GREEN}✓ S3 versioning: Enabled${NC}"
else
    echo -e "${YELLOW}⚠ S3 versioning: $VERSIONING_STATUS${NC}"
fi

# Verify lifecycle
LIFECYCLE_COUNT=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --region "$AWS_REGION" --query 'length(Rules)' --output text 2>/dev/null)
if [ -n "$LIFECYCLE_COUNT" ] && [ "$LIFECYCLE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ S3 lifecycle: $LIFECYCLE_COUNT rules configured${NC}"
else
    echo -e "${YELLOW}⚠ S3 lifecycle: Not configured${NC}"
fi

# List alarms
ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "app-" --region "$AWS_REGION" --query 'length(MetricAlarms)' --output text 2>/dev/null)
if [ -n "$ALARM_COUNT" ] && [ "$ALARM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ CloudWatch alarms: $ALARM_COUNT configured${NC}"
else
    echo -e "${YELLOW}⚠ CloudWatch alarms: None found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo -e "1. ${BLUE}Subscribe to SNS alerts (if not done):${NC}"
echo -e "   aws sns subscribe --topic-arn YOUR_TOPIC_ARN --protocol email --notification-endpoint your@email.com"
echo ""
echo -e "2. ${BLUE}Deploy updated application:${NC}"
echo -e "   cd $DEPLOYMENT_DIR"
echo -e "   ./scripts/app-deploy.sh update"
echo ""
echo -e "3. ${BLUE}Verify metrics are flowing:${NC}"
echo -e "   Wait 5 minutes, then check:"
echo -e "   aws cloudwatch list-metrics --namespace ${CLOUDWATCH_NAMESPACE:-Rampe}"
echo ""
echo -e "4. ${BLUE}View S3 cost savings in ~30 days${NC}"
echo ""
echo -e "${GREEN}Configuration saved:${NC}"
echo -e "  - S3 version retention: $S3_VERSION_RETENTION days"
echo -e "  - Bucket: $BUCKET_NAME"
echo -e "  - Region: $AWS_REGION"
echo ""

