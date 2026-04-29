# ECR Quick Start Guide

Quick reference for setting up and using AWS ECR with Jenkins CI/CD pipeline.

---

## Prerequisites

- ✅ AWS CLI installed and configured
- ✅ Jenkins server running on EC2
- ✅ Docker installed on Jenkins server
- ✅ EKS cluster created
- ✅ Proper IAM permissions

---

## Quick Setup (PowerShell)

```powershell
# Run the automated setup script
.\scripts\setup-ecr.ps1
```

This script will:
1. Create ECR repository `springboot-app`
2. Create IAM policy for Jenkins
3. Attach policy to Jenkins EC2 instance role
4. Apply lifecycle policy for automatic cleanup
5. Configure EKS node roles for ECR access

---

## Manual Setup Steps

### 1. Create ECR Repository

```powershell
# Set variables
$AWS_REGION = "us-east-1"
$REPO_NAME = "springboot-app"

# Create repository
aws ecr create-repository `
  --repository-name $REPO_NAME `
  --region $AWS_REGION `
  --image-scanning-configuration scanOnPush=true `
  --encryption-configuration encryptionType=AES256

# Get repository URI
aws ecr describe-repositories `
  --repository-names $REPO_NAME `
  --region $AWS_REGION `
  --query "repositories[0].repositoryUri" `
  --output text
```

### 2. Create IAM Policy for Jenkins

```powershell
# Create policy
aws iam create-policy `
  --policy-name JenkinsECRPolicy `
  --policy-document file://jenkins-ecr-policy.json

# Get your account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

# Policy ARN
$POLICY_ARN = "arn:aws:iam::${ACCOUNT_ID}:policy/JenkinsECRPolicy"
```

### 3. Attach Policy to Jenkins Instance Role

```powershell
# Find Jenkins instance
$JENKINS_INSTANCE_ID = aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=Jenkins-Server" "Name=instance-state-name,Values=running" `
  --query "Reservations[0].Instances[0].InstanceId" `
  --output text

# Get instance role
$INSTANCE_PROFILE_ARN = aws ec2 describe-instances `
  --instance-ids $JENKINS_INSTANCE_ID `
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" `
  --output text

# Extract role name
$ROLE_NAME = $INSTANCE_PROFILE_ARN.Split('/')[-1]

# Attach policy
aws iam attach-role-policy `
  --role-name $ROLE_NAME `
  --policy-arn $POLICY_ARN
```

### 4. Configure EKS Nodes for ECR Access

```powershell
# Get node group
$EKS_CLUSTER_NAME = "my-eks-cluster"
$NODE_GROUPS = aws eks list-nodegroups `
  --cluster-name $EKS_CLUSTER_NAME `
  --region $AWS_REGION `
  --query "nodegroups[0]" `
  --output text

# Get node role
$NODE_ROLE_ARN = aws eks describe-nodegroup `
  --cluster-name $EKS_CLUSTER_NAME `
  --nodegroup-name $NODE_GROUPS `
  --region $AWS_REGION `
  --query "nodegroup.nodeRole" `
  --output text

$NODE_ROLE_NAME = $NODE_ROLE_ARN.Split('/')[-1]

# Attach ECR read policy
aws iam attach-role-policy `
  --role-name $NODE_ROLE_NAME `
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
```

### 5. Apply Lifecycle Policy

```powershell
aws ecr put-lifecycle-policy `
  --repository-name $REPO_NAME `
  --lifecycle-policy-text file://ecr-lifecycle-policy.json `
  --region $AWS_REGION
```

---

## Install AWS CLI on Jenkins Server

SSH to Jenkins server and run:

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version

# Test ECR access (should work automatically via IAM role)
aws ecr describe-repositories --region us-east-1
```

---

## Test ECR Login from Jenkins Server

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@<jenkins-server-ip>

# Switch to jenkins user
sudo su - jenkins

# Test ECR login
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Should see: Login Succeeded
```

---

## Verify ECR Configuration

```powershell
# Check repository exists
aws ecr describe-repositories --repository-names springboot-app --region us-east-1

# Check lifecycle policy
aws ecr get-lifecycle-policy --repository-name springboot-app --region us-east-1

# Check image scanning configuration
aws ecr describe-repositories `
  --repository-names springboot-app `
  --region us-east-1 `
  --query "repositories[0].imageScanningConfiguration"

# List images (after first push)
aws ecr list-images --repository-name springboot-app --region us-east-1
```

---

## Jenkins Pipeline Changes

The Jenkinsfile has been updated with:

1. **ECR Login Stage** - Authenticates to ECR using IAM role
2. **Build Docker Image** - Tags with build number, latest, and git commit
3. **Push to ECR** - Pushes all tags to ECR
4. **ECR Image Scan** - Triggers ECR vulnerability scanning
5. **No Docker Hub credentials needed** - Uses IAM authentication

Key environment variables:
```groovy
AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
```

---

## Kubernetes Deployment Changes

The `k8s/deployment.yaml` has been updated:

1. **Image URI** - Changed from Docker Hub to ECR format
2. **No imagePullSecrets** - EKS nodes authenticate via IAM role
3. **Placeholder format** - `IMAGE_URI:IMAGE_TAG` (replaced by Jenkins)

---

## Common Commands

### Push Image Manually

```bash
# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag springboot-app:latest ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:latest

# Push image
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:latest
```

### Pull Image from EKS

```bash
# EKS nodes automatically authenticate to ECR
# Just use the ECR image URI in your deployment
kubectl set image deployment/springboot-app \
  springboot-app=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:latest \
  -n production
```

### View Image Scan Results

```bash
aws ecr describe-image-scan-findings \
  --repository-name springboot-app \
  --image-id imageTag=latest \
  --region us-east-1
```

### Delete Old Images

```bash
# List images
aws ecr list-images --repository-name springboot-app --region us-east-1

# Delete specific image
aws ecr batch-delete-image \
  --repository-name springboot-app \
  --image-ids imageTag=old-tag \
  --region us-east-1
```

---

## Troubleshooting

### ECR Login Fails

```bash
# Check IAM role is attached to Jenkins instance
aws ec2 describe-instances --instance-ids <instance-id> \
  --query "Reservations[0].Instances[0].IamInstanceProfile"

# Check IAM role has ECR permissions
aws iam list-attached-role-policies --role-name <role-name>
```

### Image Pull Fails in EKS

```bash
# Check EKS node role has ECR read permissions
kubectl describe pod <pod-name> -n production

# Check node role policies
aws iam list-attached-role-policies --role-name <node-role-name>
```

### Image Scan Fails

```bash
# Check scan status
aws ecr describe-image-scan-findings \
  --repository-name springboot-app \
  --image-id imageTag=<tag> \
  --region us-east-1

# Manually trigger scan
aws ecr start-image-scan \
  --repository-name springboot-app \
  --image-id imageTag=<tag> \
  --region us-east-1
```

---

## Cost Optimization

ECR charges for:
- **Storage**: $0.10 per GB/month
- **Data Transfer**: Standard AWS data transfer rates

To minimize costs:
1. ✅ Use lifecycle policies to delete old images
2. ✅ Keep only necessary tags
3. ✅ Compress Docker images (multi-stage builds)
4. ✅ Use same region as EKS (no cross-region transfer)

---

## Security Best Practices

1. ✅ **Use IAM roles** instead of access keys
2. ✅ **Enable image scanning** on push
3. ✅ **Enable encryption** at rest (AES-256)
4. ✅ **Use private repositories** (default)
5. ✅ **Implement lifecycle policies** for cleanup
6. ✅ **Use immutable tags** for production
7. ✅ **Monitor with CloudWatch** for unauthorized access
8. ✅ **Scan with Trivy** before pushing to ECR
9. ✅ **Review ECR scan findings** regularly
10. ✅ **Use least privilege** IAM policies

---

## Next Steps

1. ✅ Run `.\scripts\setup-ecr.ps1` to create ECR repository
2. ✅ Install AWS CLI on Jenkins server
3. ✅ Test ECR login from Jenkins server
4. ✅ Commit updated Jenkinsfile and deployment.yaml
5. ✅ Push to GitHub to trigger Jenkins pipeline
6. ✅ Monitor first build with ECR
7. ✅ Verify image appears in ECR console
8. ✅ Verify deployment pulls from ECR successfully

---

## Reference Files

- `ECR-JENKINS-SETUP.md` - Detailed ECR setup guide
- `jenkins-ecr-policy.json` - IAM policy for Jenkins
- `ecr-lifecycle-policy.json` - Lifecycle policy for cleanup
- `Jenkinsfile` - Updated pipeline with ECR stages
- `k8s/deployment.yaml` - Updated with ECR image URI
- `scripts/setup-ecr.ps1` - Automated setup script

---

**Your pipeline is now configured to use AWS ECR instead of Docker Hub!** 🚀
