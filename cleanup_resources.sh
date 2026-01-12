#!/bin/bash

# ===================================
# Complete AWS Resource Cleanup Script
# Handles: EC2, Security Groups, S3 Buckets (with versioning)
# ===================================

set -e  # Exit on any error

# -------------------------
# CONFIGURATION
# -------------------------
# Multiple project tags to search for
PROJECT_TAGS=("AutomationLab" "AutomationProject")
REGION="eu-central-1"

echo "=========================================="
echo "AWS Resource Cleanup Script"
echo "Project Tags: ${PROJECT_TAGS[*]}"
echo "Region: $REGION"
echo "=========================================="
echo ""

# -------------------------
# TERMINATE EC2 INSTANCES
# -------------------------
echo "[1/3] Checking for EC2 instances..."
INSTANCE_IDS=""

# Search for instances with any of the project tags
for TAG in "${PROJECT_TAGS[@]}"; do
    FOUND_INSTANCES=$(aws ec2 describe-instances \
        --region $REGION \
        --filters "Name=tag:Project,Values=$TAG" \
                  "Name=instance-state-name,Values=running,stopped,stopping,pending" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)
    
    if [ -n "$FOUND_INSTANCES" ]; then
        INSTANCE_IDS="$INSTANCE_IDS $FOUND_INSTANCES"
        echo "Found instances with tag Project=$TAG: $FOUND_INSTANCES"
    fi
done

# Remove leading/trailing spaces
INSTANCE_IDS=$(echo $INSTANCE_IDS | xargs)

if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating all found instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_IDS
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_IDS
    echo "✓ Instances terminated successfully"
else
    echo "✓ No EC2 instances found"
fi
echo ""

# -------------------------
# DELETE SECURITY GROUPS
# -------------------------
echo "[2/3] Checking for security groups..."
SG_IDS=""

# Search for security groups with any of the project tags
for TAG in "${PROJECT_TAGS[@]}"; do
    FOUND_SGS=$(aws ec2 describe-security-groups \
        --region $REGION \
        --filters "Name=tag:Project,Values=$TAG" \
        --query "SecurityGroups[?GroupName!='default'].GroupId" \
        --output text)
    
    if [ -n "$FOUND_SGS" ]; then
        SG_IDS="$SG_IDS $FOUND_SGS"
        echo "Found security groups with tag Project=$TAG: $FOUND_SGS"
    fi
done

# Remove leading/trailing spaces
SG_IDS=$(echo $SG_IDS | xargs)

if [ -n "$SG_IDS" ]; then
    for SG_ID in $SG_IDS; do
        echo "Deleting security group: $SG_ID"
        aws ec2 delete-security-group --region $REGION --group-id $SG_ID
        echo "✓ Deleted $SG_ID"
    done
else
    echo "✓ No security groups found"
fi
echo ""

# -------------------------
# DELETE S3 BUCKETS
# -------------------------
echo "[3/3] Checking for S3 buckets..."
BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, 'automation-lab-')].Name" \
    --output text)

if [ -n "$BUCKETS" ]; then
    for BUCKET in $BUCKETS; do
        # Verify bucket has one of the correct tags
        TAGS=$(aws s3api get-bucket-tagging --bucket $BUCKET 2>/dev/null || echo "")
        SHOULD_DELETE=false
        
        for TAG in "${PROJECT_TAGS[@]}"; do
            if echo "$TAGS" | grep -q "$TAG"; then
                SHOULD_DELETE=true
                echo "Processing bucket: $BUCKET (tag: Project=$TAG)"
                break
            fi
        done
        
        if [ "$SHOULD_DELETE" = true ]; then
            # Check if versioning is enabled
            VERSIONING=$(aws s3api get-bucket-versioning --bucket $BUCKET --query 'Status' --output text)
            
            if [ "$VERSIONING" == "Enabled" ]; then
                echo "  - Versioning is enabled, deleting all versions..."
                
                # Delete all object versions
                aws s3api list-object-versions --bucket $BUCKET --output json | \
                jq -r '.Versions[]?, .DeleteMarkers[]? | "\(.Key)\t\(.VersionId)"' | \
                while IFS=

# -------------------------
# CLEANUP KEY PAIRS (Optional)
# -------------------------
echo "[Optional] Checking for key pairs..."
KEY_NAME="automation-key"
KEY_EXISTS=$(aws ec2 describe-key-pairs \
    --region $REGION \
    --key-names $KEY_NAME \
    --query 'KeyPairs[0].KeyName' \
    --output text 2>/dev/null || echo "")

if [ "$KEY_EXISTS" == "$KEY_NAME" ]; then
    read -p "Delete key pair '$KEY_NAME'? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 delete-key-pair --region $REGION --key-name $KEY_NAME
        echo "✓ Deleted key pair: $KEY_NAME"
        if [ -f "$HOME/$KEY_NAME.pem" ]; then
            rm "$HOME/$KEY_NAME.pem"
            echo "✓ Deleted local key file"
        fi
    fi
else
    echo "✓ No key pair found"
fi
echo ""

echo "=========================================="
echo "Cleanup completed successfully!"
echo "=========================================="\t' read -r key versionId; do
                    if [ -n "$key" ] && [ -n "$versionId" ]; then
                        aws s3api delete-object --bucket $BUCKET --key "$key" --version-id "$versionId" > /dev/null
                        echo "    Deleted: $key (version: $versionId)"
                    fi
                done
            else
                echo "  - Deleting objects..."
                aws s3 rm s3://$BUCKET --recursive
            fi
            
            # Delete the bucket
            echo "  - Deleting bucket..."
            aws s3api delete-bucket --bucket $BUCKET --region $REGION
            echo "✓ Deleted bucket: $BUCKET"
        fi
    done
else
    echo "✓ No S3 buckets found"
fi
echo ""

# -------------------------
# CLEANUP KEY PAIRS (Optional)
# -------------------------
echo "[Optional] Checking for key pairs..."
KEY_NAME="automation-key"
KEY_EXISTS=$(aws ec2 describe-key-pairs \
    --region $REGION \
    --key-names $KEY_NAME \
    --query 'KeyPairs[0].KeyName' \
    --output text 2>/dev/null || echo "")

if [ "$KEY_EXISTS" == "$KEY_NAME" ]; then
    read -p "Delete key pair '$KEY_NAME'? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 delete-key-pair --region $REGION --key-name $KEY_NAME
        echo "✓ Deleted key pair: $KEY_NAME"
        if [ -f "$HOME/$KEY_NAME.pem" ]; then
            rm "$HOME/$KEY_NAME.pem"
            echo "✓ Deleted local key file"
        fi
    fi
else
    echo "✓ No key pair found"
fi
echo ""

echo "=========================================="
echo "Cleanup completed successfully!"
echo "=========================================="