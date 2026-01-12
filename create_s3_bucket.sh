#!/bin/bash
set -e

PROJECT_TAG="AutomationLab"
REGION=$(aws configure get region)
BUCKET_NAME="automation-lab-$RANDOM-$RANDOM"

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

echo "Tagging bucket..."
aws s3api put-bucket-tagging \
  --bucket $BUCKET_NAME \
  --tagging "TagSet=[{Key=Project,Value=$PROJECT_TAG}]"

echo "Uploading file..."
aws s3 cp welcome.txt s3://$BUCKET_NAME/

echo "S3 Bucket Created Successfully!"
echo "Bucket Name: $BUCKET_NAME"

