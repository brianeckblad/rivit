#!/bin/bash
#
# EC2 Instance Creation with IAM Role
# Creates EC2 instance with proper VPC, security groups, and IAM role attached
#
# Prerequisites: IAM role must exist (created by iam-role-setup.sh)
# Usage: Called by infra-complete-setup.sh or run standalone
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration from environment or parameters
INSTANCE_NAME="${INSTANCE_NAME:-app-item-listing-tool}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.nano}"
AWS_REGION="${AWS_REGION:-us-east-1}"
IAM_INSTANCE_PROFILE="${IAM_INSTANCE_PROFILE:-}"
KEY_NAME="${KEY_NAME:-${INSTANCE_NAME}-key}"

echo -e "${BLUE}▶ Creating EC2 instance: $INSTANCE_NAME${NC}"
echo -e "  Instance type: $INSTANCE_TYPE"
echo -e "  Region: $AWS_REGION"
echo -e "  IAM profile: ${IAM_INSTANCE_PROFILE:-None}"

#############################################
# Step 1: Create VPC (if not exists)
#############################################

echo -e "${BLUE}▶ Setting up VPC...${NC}"

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" = "None" ]; then
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${INSTANCE_NAME}-vpc}]" \
        --query 'Vpc.VpcId' \
        --output text)

    echo -e "${GREEN}✓ VPC created: $VPC_ID${NC}"

    # Enable DNS
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
else
    echo -e "${YELLOW}⚠ VPC already exists: $VPC_ID${NC}"
fi

#############################################
# Step 2: Create Internet Gateway
#############################################

echo -e "${BLUE}▶ Setting up Internet Gateway...${NC}"

IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}-igw" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text 2>/dev/null || echo "None")

if [ "$IGW_ID" = "None" ]; then
    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${INSTANCE_NAME}-igw}]" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)

    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
    echo -e "${GREEN}✓ Internet Gateway created: $IGW_ID${NC}"
else
    echo -e "${YELLOW}⚠ Internet Gateway already exists: $IGW_ID${NC}"
fi

#############################################
# Step 3: Create Subnet
#############################################

echo -e "${BLUE}▶ Setting up Subnet...${NC}"

SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}-subnet" \
    --query 'Subnets[0].SubnetId' \
    --output text 2>/dev/null || echo "None")

if [ "$SUBNET_ID" = "None" ]; then
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.1.0/24 \
        --availability-zone "${AWS_REGION}a" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${INSTANCE_NAME}-subnet}]" \
        --query 'Subnet.SubnetId' \
        --output text)

    # Enable auto-assign public IP
    aws ec2 modify-subnet-attribute \
        --subnet-id "$SUBNET_ID" \
        --map-public-ip-on-launch

    echo -e "${GREEN}✓ Subnet created: $SUBNET_ID${NC}"
else
    echo -e "${YELLOW}⚠ Subnet already exists: $SUBNET_ID${NC}"
fi

#############################################
# Step 4: Create Route Table
#############################################

echo -e "${BLUE}▶ Setting up Route Table...${NC}"

ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${INSTANCE_NAME}-rt" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null || echo "None")

if [ "$ROUTE_TABLE_ID" = "None" ]; then
    ROUTE_TABLE_ID=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${INSTANCE_NAME}-rt}]" \
        --query 'RouteTable.RouteTableId' \
        --output text)

    # Add route to internet gateway
    aws ec2 create-route \
        --route-table-id "$ROUTE_TABLE_ID" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$IGW_ID"

    # Associate with subnet
    aws ec2 associate-route-table \
        --route-table-id "$ROUTE_TABLE_ID" \
        --subnet-id "$SUBNET_ID"

    echo -e "${GREEN}✓ Route Table created: $ROUTE_TABLE_ID${NC}"
else
    echo -e "${YELLOW}⚠ Route Table already exists: $ROUTE_TABLE_ID${NC}"
fi

#############################################
# Step 5: Create Security Group
#############################################

echo -e "${BLUE}▶ Setting up Security Group...${NC}"

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name "${INSTANCE_NAME}-sg" \
        --description "Security group for $INSTANCE_NAME" \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${INSTANCE_NAME}-sg}]" \
        --query 'GroupId' \
        --output text)

    # Allow HTTP (80)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0

    # Allow HTTPS (443)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0

    # Allow SSH (22) - for initial setup only, will be removed after SSM is configured
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 2>/dev/null || true

    echo -e "${GREEN}✓ Security Group created: $SG_ID${NC}"
else
    echo -e "${YELLOW}⚠ Security Group already exists: $SG_ID${NC}"
fi

#############################################
# Step 6: Get Latest Ubuntu 22.04 AMI
#############################################

echo -e "${BLUE}▶ Finding latest Ubuntu 22.04 AMI...${NC}"

AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo -e "${GREEN}✓ Using AMI: $AMI_ID${NC}"

#############################################
# Step 7: Create SSH Key Pair (if needed)
#############################################

echo -e "${BLUE}▶ Setting up SSH key pair...${NC}"

if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" 2>/dev/null; then
    # Create key pair
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/${KEY_NAME}.pem

    chmod 600 ~/.ssh/${KEY_NAME}.pem
    echo -e "${GREEN}✓ SSH key created: ~/.ssh/${KEY_NAME}.pem${NC}"
else
    echo -e "${YELLOW}⚠ SSH key already exists: $KEY_NAME${NC}"
fi

#############################################
# Step 8: Create EC2 Instance
#############################################

echo -e "${BLUE}▶ Creating EC2 instance...${NC}"

# Check if instance already exists
EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_INSTANCE" != "None" ]; then
    echo -e "${YELLOW}⚠ Instance already exists: $EXISTING_INSTANCE${NC}"
    INSTANCE_ID="$EXISTING_INSTANCE"
else
    # Build run-instances command
    RUN_INSTANCES_CMD="aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SG_ID \
        --subnet-id $SUBNET_ID \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]' \
        --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3,DeleteOnTermination=true}'"

    # Add IAM instance profile if provided
    if [ -n "$IAM_INSTANCE_PROFILE" ]; then
        RUN_INSTANCES_CMD="$RUN_INSTANCES_CMD --iam-instance-profile Name=$IAM_INSTANCE_PROFILE"
        echo -e "${GREEN}✓ Will attach IAM instance profile: $IAM_INSTANCE_PROFILE${NC}"
    fi

    # Create instance
    INSTANCE_ID=$(eval "$RUN_INSTANCES_CMD" --query 'Instances[0].InstanceId' --output text)

    echo -e "${GREEN}✓ EC2 instance created: $INSTANCE_ID${NC}"
    echo -e "${YELLOW}⏳ Waiting for instance to be running...${NC}"

    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    echo -e "${GREEN}✓ Instance is running${NC}"
fi

#############################################
# Step 9: Get Instance Details
#############################################

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

INSTANCE_DNS=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicDnsName' \
    --output text)

echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}EC2 Instance Created Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo -e "${BLUE}Instance ID:${NC} $INSTANCE_ID"
echo -e "${BLUE}Public IP:${NC} $INSTANCE_IP"
echo -e "${BLUE}Public DNS:${NC} $INSTANCE_DNS"
echo -e "${BLUE}Instance Type:${NC} $INSTANCE_TYPE"
echo -e "${BLUE}VPC ID:${NC} $VPC_ID"
echo -e "${BLUE}Subnet ID:${NC} $SUBNET_ID"
echo -e "${BLUE}Security Group:${NC} $SG_ID"
if [ -n "$IAM_INSTANCE_PROFILE" ]; then
    echo -e "${BLUE}IAM Instance Profile:${NC} $IAM_INSTANCE_PROFILE"
fi
echo

# Export for use by calling scripts
export EC2_INSTANCE_ID="$INSTANCE_ID"
export EC2_PUBLIC_IP="$INSTANCE_IP"
export EC2_VPC_ID="$VPC_ID"
export EC2_SUBNET_ID="$SUBNET_ID"
export EC2_SECURITY_GROUP_ID="$SG_ID"

# Save to file for sourcing
cat > "/tmp/ec2-instance-info.sh" <<EOF
export EC2_INSTANCE_ID="$INSTANCE_ID"
export EC2_PUBLIC_IP="$INSTANCE_IP"
export EC2_VPC_ID="$VPC_ID"
export EC2_SUBNET_ID="$SUBNET_ID"
export EC2_SECURITY_GROUP_ID="$SG_ID"
EOF

echo -e "${GREEN}✓ Instance info saved to: /tmp/ec2-instance-info.sh${NC}"
echo -e "${BLUE}  Source it with: source /tmp/ec2-instance-info.sh${NC}"
echo

