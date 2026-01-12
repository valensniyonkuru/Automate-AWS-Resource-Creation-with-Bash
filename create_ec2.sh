#!/bin/bash

# ===================================
# EC2 Instance Creation Script
# Region: Frankfurt (eu-central-1)
# ===================================

set -e  # Exit on any error

# -------------------------
# CONFIGURATION VARIABLES
# -------------------------
REGION="eu-central-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="automation-key"
KEY_PATH="$HOME/$KEY_NAME.pem"
PROJECT_TAG="AutomationProject"
SECURITY_GROUP_NAME="automation-sg"
SECURITY_GROUP_DESC="Security group for automation project"

# -------------------------
# FETCH LATEST AMAZON LINUX 2 AMI
# -------------------------
echo "Fetching latest Amazon Linux 2 AMI in $REGION..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text \
    --region "$REGION")

if [ -z "$AMI_ID" ]; then
    echo "Error: Could not fetch AMI ID"
    exit 1
fi

echo "Using AMI: $AMI_ID"

# -------------------------
# CREATE KEY PAIR IF NOT EXISTS
# -------------------------
if [ -f "$KEY_PATH" ]; then
    echo "Key file already exists at $KEY_PATH. Skipping creation."
else
    echo "Creating new key pair: $KEY_NAME"
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text \
        --region "$REGION" > "$KEY_PATH"
    
    chmod 400 "$KEY_PATH"
    echo "Key pair created and saved to $KEY_PATH"
fi

# -------------------------
# CREATE SECURITY GROUP IF NOT EXISTS
# -------------------------
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "None")

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating security group: $SECURITY_GROUP_NAME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "$SECURITY_GROUP_DESC" \
        --query 'GroupId' \
        --output text \
        --region "$REGION")
    
    echo "Security group created: $SG_ID"
    
    # Add SSH access rule
    echo "Adding SSH inbound rule to security group..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$REGION"
    
    echo "SSH access rule added"
else
    echo "Using existing security group: $SG_ID"
fi

# -------------------------
# LAUNCH EC2 INSTANCE
# -------------------------
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=AutomationInstance},{Key=Project,Value=$PROJECT_TAG}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region "$REGION")

if [ -z "$INSTANCE_ID" ]; then
    echo "Error: Failed to launch EC2 instance"
    exit 1
fi

echo "Instance launched: $INSTANCE_ID"

# -------------------------
# WAIT FOR INSTANCE TO BE RUNNING
# -------------------------
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION"

echo "Instance is now running!"

# -------------------------
# FETCH PUBLIC IP
# -------------------------
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region "$REGION")

# -------------------------
# DISPLAY RESULTS
# -------------------------
echo ""
echo "=========================================="
echo "  EC2 Instance Created Successfully!"
echo "=========================================="
echo "Region       : $REGION"
echo "Instance ID  : $INSTANCE_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "AMI ID       : $AMI_ID"
echo "Public IP    : $PUBLIC_IP"
echo "Key Path     : $KEY_PATH"
echo "Security Group: $SG_ID"
echo ""
echo "SSH Command:"
echo "  ssh -i $KEY_PATH ec2-user@$PUBLIC_IP"
echo ""
echo "=========================================="
echo ""
echo "Note: It may take a few moments for SSH to become available."
echo "You can test the connection with:"
echo "  ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP"
echo "=========================================="
