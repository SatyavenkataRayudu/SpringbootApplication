#!/bin/bash

# Cleanup script to remove all resources
set -e

echo "========================================="
echo "Cleanup Script"
echo "========================================="

read -p "AWS Region: " AWS_REGION
read -p "EKS Cluster Name: " CLUSTER_NAME
read -p "S3 Bucket Name: " S3_BUCKET

echo ""
echo "WARNING: This will delete:"
echo "- EKS Cluster: $CLUSTER_NAME"
echo "- S3 Bucket: $S3_BUCKET (and all contents)"
echo "- All associated resources"
echo ""
read -p "Are you sure? Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Delete Kubernetes resources
echo "Deleting Kubernetes resources..."
kubectl delete namespace production --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

# Delete EKS cluster
echo "Deleting EKS cluster (this will take 10-15 minutes)..."
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

# Empty and delete S3 bucket
echo "Emptying S3 bucket..."
aws s3 rm s3://$S3_BUCKET --recursive --region $AWS_REGION

echo "Deleting S3 bucket..."
aws s3 rb s3://$S3_BUCKET --region $AWS_REGION

echo "Cleanup completed!"
