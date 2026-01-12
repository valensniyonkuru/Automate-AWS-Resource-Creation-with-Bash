#!/bin/bash
set -e

GROUP_NAME="devops-sg"
DESCRIPTION="DevOps Security Group"
PROJECT_TAG="AutomationLab"

VPC_ID=$(aws ec2 describe-vpcs \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "Creating security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name $GROUP_NAME \
  --description "$DESCRIPTION" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 create-tags \
  --resources $SG_ID \
  --tags Key=Project,Value=$PROJECT_TAG

echo "Authorizing inbound rules..."
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

echo "Security Group Created:"
aws ec2 describe-security-groups --group-ids $SG_ID
