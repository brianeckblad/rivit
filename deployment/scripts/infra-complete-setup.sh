#!/bin/bash
#
# Complete AWS Infrastructure Setup with CloudFront, WAF, and Secrets Manager
# This script creates a production-ready, DDoS-protected infrastructure
#
# Usage: ./infra-complete-setup.sh [secrets-file]
#
# If secrets-file is provided, secrets will be uploaded to AWS Secrets Manager
# Example: ./infra-complete-setup.sh secrets.env
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load secrets file if provided
SECRETS_FILE="${1:-}"
if [ -n "$SECRETS_FILE" ] && [ -f "$SECRETS_FILE" ]; then
    echo -e "${BLUE}Loading secrets from: $SECRETS_FILE${NC}"
    set -a
    source "$SECRETS_FILE"
    set +a
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║   AWS Complete Infrastructure Setup                      ║${NC}"
echo -e "${CYAN}║   EC2 + CloudFront + WAF + Secrets Manager               ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Check for required tools
echo -e "${BLUE}▶ Checking prerequisites...${NC}"

MISSING_TOOLS=()

if ! command -v aws &> /dev/null; then
    MISSING_TOOLS+=("aws-cli")
fi

if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}⚠ Ansible not installed (will be needed for deployment)${NC}"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Missing required tools: ${MISSING_TOOLS[*]}${NC}"
    echo
    echo -e "Install with:"
    echo -e "  pip install awscli"
    echo -e "  brew install jq  # macOS"
    echo -e "  sudo apt-get install jq  # Ubuntu"
    exit 1
fi

echo -e "${GREEN}✓ All required tools found${NC}"
echo

# Get configuration
echo -e "${BLUE}▶ Configuration${NC}"
echo

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo
fi

if [ -z "$AWS_REGION" ]; then
    read -p "AWS Region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
fi

if [ -z "$S3_BUCKET_NAME" ]; then
    read -p "S3 Bucket Name: " S3_BUCKET_NAME
fi

if [ -z "$INSTANCE_NAME" ]; then
    read -p "Instance Name (default: app-item-listing-tool): " INSTANCE_NAME
    INSTANCE_NAME=${INSTANCE_NAME:-app-item-listing-tool}
fi

if [ -z "$INSTANCE_TYPE" ]; then
    read -p "Instance Type (default: t3.micro): " INSTANCE_TYPE
    INSTANCE_TYPE=${INSTANCE_TYPE:-t3.micro}
fi

if [ -z "$CLOUDFRONT_PRICE_CLASS" ]; then
    echo
    echo "CloudFront Price Classes:"
    echo "  1) PriceClass_100 - US, Canada, Europe (Cheapest)"
    echo "  2) PriceClass_200 - Above + Asia, South America"
    echo "  3) PriceClass_All - All edge locations"
    read -p "Select (1-3, default: 1): " PRICE_CHOICE
    case "${PRICE_CHOICE:-1}" in
        1) CLOUDFRONT_PRICE_CLASS="PriceClass_100" ;;
        2) CLOUDFRONT_PRICE_CLASS="PriceClass_200" ;;
        3) CLOUDFRONT_PRICE_CLASS="PriceClass_All" ;;
        *) CLOUDFRONT_PRICE_CLASS="PriceClass_100" ;;
    esac
fi

echo

# Configure AWS CLI
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="$AWS_REGION"

# Verify AWS credentials
echo -e "${BLUE}▶ Verifying AWS credentials...${NC}"
if ! ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo -e "${RED}✗ Invalid AWS credentials${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials verified (Account: $ACCOUNT_ID)${NC}"
echo

#############################################
# Phase 1: IAM Role Setup
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 1: IAM Role Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

# Create IAM role for EC2 instance
ROLE_NAME="${INSTANCE_NAME}-ec2-role"

if [ -f "$SCRIPT_DIR/iam-role-setup.sh" ]; then
    bash "$SCRIPT_DIR/iam-role-setup.sh" "$ROLE_NAME" "$S3_BUCKET_NAME" "$AWS_REGION"

    # Source the role info
    if [ -f "/tmp/iam-role-info.sh" ]; then
        source "/tmp/iam-role-info.sh"
        echo -e "${GREEN}✓ IAM role ready: $IAM_INSTANCE_PROFILE${NC}"
    fi
else
    echo -e "${YELLOW}⚠ IAM role setup script not found, creating basic role...${NC}"

    # Fallback: Create basic IAM role inline
    TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

    if ! aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
        aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST_POLICY"
    fi

    # Attach SSM policy
    aws iam attach-role-policy --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" 2>/dev/null || true

    # Create instance profile
    PROFILE_NAME="${ROLE_NAME}-profile"
    if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null; then
        aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
        sleep 2
        aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME"
    fi

    export IAM_INSTANCE_PROFILE="$PROFILE_NAME"
    echo -e "${GREEN}✓ Basic IAM role created: $IAM_INSTANCE_PROFILE${NC}"
fi

echo

#############################################
# Phase 2: EC2 Infrastructure
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 2: EC2 Infrastructure${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

# Run EC2 creation script
EC2_CREATE_SCRIPT="$SCRIPT_DIR/ec2-create-instance.sh"

if [ -f "$EC2_CREATE_SCRIPT" ]; then
    echo -e "${BLUE}▶ Creating EC2 instance with IAM role...${NC}"

    # Export configuration for EC2 script
    export INSTANCE_NAME
    export INSTANCE_TYPE
    export AWS_REGION
    export IAM_INSTANCE_PROFILE
    export KEY_NAME="${INSTANCE_NAME}-key"

    # Run EC2 creation
    bash "$EC2_CREATE_SCRIPT"

    # Source the instance info
    if [ -f "/tmp/ec2-instance-info.sh" ]; then
        source "/tmp/ec2-instance-info.sh"
        INSTANCE_ID="$EC2_INSTANCE_ID"
        INSTANCE_IP="$EC2_PUBLIC_IP"
        echo -e "${GREEN}✓ EC2 instance created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to get EC2 instance info${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ EC2 creation script not found: $EC2_CREATE_SCRIPT${NC}"
    echo -e "${YELLOW}  This script creates proper EC2 instances with VPC, security groups, and IAM roles.${NC}"
    echo -e "${YELLOW}  The old infra-ec2-setup.sh script creates Lightsail instances (deprecated).${NC}"
    exit 1
fi

echo

#############################################
# Phase 3: Secrets Manager Setup
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 3: AWS Secrets Manager${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

SECRET_NAME="${INSTANCE_NAME}/production"

# Check if we have secrets to upload
if [ -n "$SECRET_KEY" ] || [ -n "$SECRETS_FILE" ]; then
    echo -e "${BLUE}▶ Creating secrets in Secrets Manager...${NC}"

    # Build secrets JSON
    SECRETS_JSON=$(cat <<EOF
{
  "SECRET_KEY": "${SECRET_KEY:-$(python3 -c 'import secrets; print(secrets.token_hex(32))')}",
  "AWS_REGION": "$AWS_REGION",
  "S3_BUCKET_NAME": "$S3_BUCKET_NAME",
  "S3_FOLDER": "${S3_FOLDER:-production}",
  "EBAY_PRODUCTION_APP_ID": "${EBAY_PRODUCTION_APP_ID:-}",
  "EBAY_PRODUCTION_DEV_ID": "${EBAY_PRODUCTION_DEV_ID:-}",
  "EBAY_PRODUCTION_CERT_ID": "${EBAY_PRODUCTION_CERT_ID:-}",
  "EBAY_PRODUCTION_TOKEN": "${EBAY_PRODUCTION_TOKEN:-}",
  "EBAY_SANDBOX_APP_ID": "${EBAY_SANDBOX_APP_ID:-}",
  "EBAY_SANDBOX_DEV_ID": "${EBAY_SANDBOX_DEV_ID:-}",
  "EBAY_SANDBOX_CERT_ID": "${EBAY_SANDBOX_CERT_ID:-}",
  "EBAY_SANDBOX_TOKEN": "${EBAY_SANDBOX_TOKEN:-}",
  "ADMIN_USERNAME": "${ADMIN_USERNAME:-admin}",
  "ADMIN_PASSWORD": "${ADMIN_PASSWORD:-}",
  "APP_SECRET_TOKEN": "${APP_SECRET_TOKEN:-$(python3 -c 'import secrets; print(secrets.token_hex(16))')}",
  "GITHUB_TOKEN": "${GITHUB_TOKEN:-}",
  "GITHUB_REPO": "${GITHUB_REPO:-}",
  "GITHUB_BRANCH": "${GITHUB_BRANCH:-main}"
}
EOF
)

    # Create or update secret
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Secret already exists, updating...${NC}"
        aws secretsmanager put-secret-value \
            --secret-id "$SECRET_NAME" \
            --secret-string "$SECRETS_JSON"
    else
        aws secretsmanager create-secret \
            --name "$SECRET_NAME" \
            --description "Production secrets for $INSTANCE_NAME" \
            --secret-string "$SECRETS_JSON"
    fi

    echo -e "${GREEN}✓ Secrets stored in: $SECRET_NAME${NC}"

    # Update EC2 IAM role to access Secrets Manager
    ROLE_NAME="${INSTANCE_NAME}-ec2-role"

    echo -e "${BLUE}▶ Adding Secrets Manager permissions to EC2 role...${NC}"

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
      "Resource": "arn:aws:secretsmanager:$AWS_REGION:$ACCOUNT_ID:secret:${INSTANCE_NAME}/*"
    }
  ]
}
EOF
)

    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "SecretsManagerAccess" \
        --policy-document "$SECRETS_POLICY"

    echo -e "${GREEN}✓ Secrets Manager access granted to EC2${NC}"
else
    echo -e "${YELLOW}⚠ No secrets file provided, skipping Secrets Manager setup${NC}"
    echo -e "${YELLOW}  You'll need to configure secrets manually or run:${NC}"
    echo -e "${YELLOW}  ./scripts/secrets-manager-setup.sh secrets.env${NC}"
fi

echo

#############################################
# Phase 4: CloudFront Distribution
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 4: CloudFront CDN${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

echo -e "${BLUE}▶ Creating CloudFront distribution...${NC}"
echo -e "${YELLOW}  This may take 10-15 minutes...${NC}"

# Generate unique caller reference
CALLER_REF="$INSTANCE_NAME-$(date +%s)"

# Create distribution configuration
CF_CONFIG=$(cat <<EOF
{
  "CallerReference": "$CALLER_REF",
  "Comment": "CDN for $INSTANCE_NAME",
  "Enabled": true,
  "PriceClass": "$CLOUDFRONT_PRICE_CLASS",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "ec2-origin",
        "DomainName": "$INSTANCE_IP",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 3,
            "Items": ["TLSv1.2", "TLSv1.1", "TLSv1"]
          }
        },
        "CustomHeaders": {
          "Quantity": 1,
          "Items": [
            {
              "HeaderName": "X-Custom-CloudFront-Header",
              "HeaderValue": "$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
            }
          ]
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "ec2-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["HEAD", "GET"]
      }
    },
    "ForwardedValues": {
      "QueryString": true,
      "Cookies": {
        "Forward": "all"
      },
      "Headers": {
        "Quantity": 4,
        "Items": ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Desktop-Viewer", "CloudFront-Viewer-Country"]
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 300,
    "MaxTTL": 31536000,
    "Compress": true
  }
}
EOF
)

# Create distribution
CF_OUTPUT=$(aws cloudfront create-distribution --distribution-config "$CF_CONFIG" 2>&1)

if [ $? -eq 0 ]; then
    CF_ID=$(echo "$CF_OUTPUT" | jq -r '.Distribution.Id')
    CF_DOMAIN=$(echo "$CF_OUTPUT" | jq -r '.Distribution.DomainName')

    echo -e "${GREEN}✓ CloudFront distribution created${NC}"
    echo -e "${GREEN}  Distribution ID: $CF_ID${NC}"
    echo -e "${GREEN}  Domain: $CF_DOMAIN${NC}"
    echo -e "${YELLOW}  Status: Deploying (10-15 minutes)${NC}"

    # Save CloudFront details
    echo "CLOUDFRONT_DISTRIBUTION_ID=$CF_ID" >> "$DEPLOYMENT_DIR/.deployment-config"
    echo "CLOUDFRONT_DOMAIN=$CF_DOMAIN" >> "$DEPLOYMENT_DIR/.deployment-config"

    # Update secret with CloudFront domain
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" 2>/dev/null; then
        UPDATED_SECRETS=$(echo "$SECRETS_JSON" | jq ". + {\"CLOUDFRONT_DOMAIN\": \"$CF_DOMAIN\"}")
        aws secretsmanager put-secret-value \
            --secret-id "$SECRET_NAME" \
            --secret-string "$UPDATED_SECRETS"
    fi
else
    echo -e "${RED}✗ Failed to create CloudFront distribution${NC}"
    echo "$CF_OUTPUT"
fi

echo

#############################################
# Phase 5: AWS WAF
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 5: AWS WAF (Web Application Firewall)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

echo -e "${BLUE}▶ Creating WAF Web ACL...${NC}"

WAF_NAME="${INSTANCE_NAME}-waf"

# Create WAF Web ACL
WAF_CONFIG=$(cat <<'EOFWAF'
{
  "Name": "INSTANCE_NAME-waf",
  "Scope": "CLOUDFRONT",
  "DefaultAction": {
    "Allow": {}
  },
  "Rules": [
    {
      "Name": "AWSManagedRulesCommonRuleSet",
      "Priority": 1,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesCommonRuleSetMetric"
      }
    },
    {
      "Name": "AWSManagedRulesKnownBadInputsRuleSet",
      "Priority": 2,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesKnownBadInputsRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWSManagedRulesKnownBadInputsRuleSetMetric"
      }
    },
    {
      "Name": "RateLimitRule",
      "Priority": 3,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 2000,
          "AggregateKeyType": "IP"
        }
      },
      "Action": {
        "Block": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitRuleMetric"
      }
    }
  ],
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "INSTANCE_NAME-waf-metric"
  }
}
EOFWAF
)

# Replace INSTANCE_NAME placeholder
WAF_CONFIG=$(echo "$WAF_CONFIG" | sed "s/INSTANCE_NAME/$INSTANCE_NAME/g")

# Create Web ACL
WAF_OUTPUT=$(aws wafv2 create-web-acl \
    --scope CLOUDFRONT \
    --region us-east-1 \
    --cli-input-json "$WAF_CONFIG" 2>&1)

if [ $? -eq 0 ]; then
    WAF_ID=$(echo "$WAF_OUTPUT" | jq -r '.Summary.Id')
    WAF_ARN=$(echo "$WAF_OUTPUT" | jq -r '.Summary.ARN')

    echo -e "${GREEN}✓ WAF Web ACL created${NC}"
    echo -e "${GREEN}  WAF ID: $WAF_ID${NC}"

    # Save WAF details
    echo "WAF_WEB_ACL_ID=$WAF_ID" >> "$DEPLOYMENT_DIR/.deployment-config"
    echo "WAF_WEB_ACL_ARN=$WAF_ARN" >> "$DEPLOYMENT_DIR/.deployment-config"

    # Associate WAF with CloudFront (if CloudFront was created)
    if [ -n "$CF_ID" ]; then
        echo -e "${BLUE}▶ Associating WAF with CloudFront...${NC}"

        # Wait for CloudFront to be ready
        echo -e "${YELLOW}  Waiting for CloudFront distribution to be deployed...${NC}"
        aws cloudfront wait distribution-deployed --id "$CF_ID"

        # Update CloudFront to use WAF
        CF_ETAG=$(aws cloudfront get-distribution-config --id "$CF_ID" --query 'ETag' --output text)
        CF_CURRENT_CONFIG=$(aws cloudfront get-distribution-config --id "$CF_ID" --query 'DistributionConfig')

        CF_UPDATED_CONFIG=$(echo "$CF_CURRENT_CONFIG" | jq ". + {\"WebACLId\": \"$WAF_ARN\"}")

        aws cloudfront update-distribution \
            --id "$CF_ID" \
            --distribution-config "$CF_UPDATED_CONFIG" \
            --if-match "$CF_ETAG"

        echo -e "${GREEN}✓ WAF associated with CloudFront${NC}"
    fi
else
    echo -e "${RED}✗ Failed to create WAF Web ACL${NC}"
    echo "$WAF_OUTPUT"
fi

echo

#############################################
# Phase 6: Application Deployment
#############################################

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 6: Application Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo

echo -e "${BLUE}▶ Deploying application...${NC}"

# Wait for instance to be fully ready
echo -e "${YELLOW}  Waiting for instance to be ready...${NC}"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"

# Update inventory file with instance IP
INVENTORY_FILE="$DEPLOYMENT_DIR/inventories/production/hosts.yml"
SSH_KEY="$HOME/.ssh/${INSTANCE_NAME}-key.pem"
echo -e "${BLUE}▶ Updating inventory file with instance IP...${NC}"

cat > "$INVENTORY_FILE" << EOF
---
# Production Inventory
# Auto-generated by infra-complete-setup.sh

all:
  children:
    production:
      hosts:
        prod:
          ansible_host: $INSTANCE_IP
          ansible_user: ubuntu
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_private_key_file: $SSH_KEY
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

      vars:
        env_name: production
EOF

echo -e "${GREEN}✓ Inventory updated: $INSTANCE_IP${NC}"

# Wait for SSH to be ready
SSH_KEY="$HOME/.ssh/${INSTANCE_NAME}-key.pem"
echo -e "${YELLOW}  Waiting for SSH to be ready...${NC}"
if [ -f "$SSH_KEY" ]; then
    for i in {1..30}; do
        if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$INSTANCE_IP "echo SSH ready" 2>/dev/null; then
            echo -e "${GREEN}✓ SSH is ready${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${YELLOW}⚠ SSH connection timeout - may need manual verification${NC}"
        fi
        sleep 10
    done
else
    echo -e "${YELLOW}⚠ SSH key not found: $SSH_KEY${NC}"
    echo -e "${YELLOW}  SSM Session Manager can be used instead${NC}"
fi

# Deploy application
if [ -f "$SCRIPT_DIR/app-deploy.sh" ]; then
    bash "$SCRIPT_DIR/app-deploy.sh" setup
    echo -e "${GREEN}✓ Application deployed${NC}"
else
    echo -e "${YELLOW}⚠ Deployment script not found, skipping application deployment${NC}"
    echo -e "${YELLOW}  Run manually: ./scripts/app-deploy.sh setup${NC}"
fi

echo

#############################################
# Summary
#############################################

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║   Setup Complete!                                        ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${GREEN}Resources Created:${NC}"
echo
echo -e "${BLUE}EC2 Instance:${NC}"
echo -e "  Instance ID: ${GREEN}$INSTANCE_ID${NC}"
echo -e "  Public IP: ${GREEN}$INSTANCE_IP${NC}"
echo -e "  Type: ${INSTANCE_TYPE}"
echo

if [ -n "$CF_DOMAIN" ]; then
    echo -e "${BLUE}CloudFront CDN:${NC}"
    echo -e "  Distribution ID: ${GREEN}$CF_ID${NC}"
    echo -e "  Domain: ${GREEN}$CF_DOMAIN${NC}"
    echo -e "  Status: ${YELLOW}Deploying (wait 10-15 minutes)${NC}"
    echo
fi

if [ -n "$WAF_ID" ]; then
    echo -e "${BLUE}AWS WAF:${NC}"
    echo -e "  Web ACL ID: ${GREEN}$WAF_ID${NC}"
    echo -e "  Protection: ${GREEN}Active${NC}"
    echo
fi

echo -e "${BLUE}Secrets Manager:${NC}"
echo -e "  Secret Name: ${GREEN}$SECRET_NAME${NC}"
echo -e "  Status: ${GREEN}Configured${NC}"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo
echo -e "${BLUE}1. Wait for CloudFront deployment:${NC}"
echo -e "   aws cloudfront get-distribution --id $CF_ID --query 'Distribution.Status'"
echo

echo -e "${BLUE}2. Update DNS to point to CloudFront:${NC}"
echo -e "   Type: CNAME"
echo -e "   Name: yourdomain.com (or subdomain)"
echo -e "   Value: ${GREEN}$CF_DOMAIN${NC}"
echo

echo -e "${BLUE}3. Test CloudFront access:${NC}"
echo -e "   curl -I https://$CF_DOMAIN"
echo

echo -e "${BLUE}4. Connect via SSM:${NC}"
echo -e "   aws ssm start-session --target $INSTANCE_ID"
echo

echo -e "${BLUE}5. Monitor in CloudWatch:${NC}"
echo -e "   https://console.aws.amazon.com/cloudwatch/"
echo

# Save complete summary
SUMMARY_FILE="$DEPLOYMENT_DIR/deployment-summary.txt"
cat > "$SUMMARY_FILE" << EOF
Complete Infrastructure Deployment Summary
Generated: $(date)
════════════════════════════════════════════════════════════

INFRASTRUCTURE:
──────────────
EC2 Instance ID: $INSTANCE_ID
EC2 Public IP: $INSTANCE_IP
EC2 Type: $INSTANCE_TYPE

CloudFront Distribution ID: $CF_ID
CloudFront Domain: $CF_DOMAIN

WAF Web ACL ID: $WAF_ID

Secrets Manager: $SECRET_NAME

CONFIGURATION:
──────────────
Region: $AWS_REGION
S3 Bucket: $S3_BUCKET_NAME
Price Class: $CLOUDFRONT_PRICE_CLASS

ACCESS:
───────
SSM: aws ssm start-session --target $INSTANCE_ID
CloudFront: https://$CF_DOMAIN

DNS CONFIGURATION:
──────────────────
Type: CNAME
Name: your-domain.com
Value: $CF_DOMAIN
TTL: 300

MONITORING:
───────────
CloudWatch Dashboards: https://console.aws.amazon.com/cloudwatch/
WAF Metrics: https://console.aws.amazon.com/wafv2/

════════════════════════════════════════════════════════════
EOF

echo -e "${GREEN}✓ Summary saved to: ${BLUE}$SUMMARY_FILE${NC}"
echo

