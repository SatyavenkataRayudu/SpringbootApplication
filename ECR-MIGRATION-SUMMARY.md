# ECR Migration Summary

Summary of changes made to migrate from Docker Hub to AWS ECR.

---

## Files Modified

### 1. Jenkinsfile ✅

**Changed:**
- Removed Docker Hub username variable
- Added AWS Account ID detection
- Added ECR registry and repository variables
- Replaced Docker Hub login with ECR login
- Updated image tagging to use ECR URI format
- Added ECR image scanning stage
- Added release tagging for main branch
- Updated cleanup to remove ECR images

**Key Changes:**
```groovy
// OLD
DOCKER_USERNAME = 'YOUR_DOCKERHUB_USERNAME'
IMAGE_NAME = "${DOCKER_USERNAME}/${APP_NAME}"

// NEW
AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
```

**New Stages:**
- `ECR Login` - Authenticates to ECR using IAM role
- `ECR Image Scan` - Triggers ECR vulnerability scanning
- `Tag Release` - Tags production releases

### 2. k8s/deployment.yaml ✅

**Changed:**
- Updated image reference from Docker Hub to ECR format
- Removed `imagePullSecrets` (not needed with IAM)
- Changed placeholder to `IMAGE_URI:IMAGE_TAG`

**Key Changes:**
```yaml
# OLD
image: YOUR_DOCKERHUB_USERNAME/springboot-app:1.0.0
imagePullSecrets:
- name: docker-registry-secret

# NEW
image: IMAGE_URI:IMAGE_TAG
# No imagePullSecrets needed - EKS nodes have ECR access via IAM role
```

---

## Files Created

### 1. jenkins-ecr-policy.json ✅

IAM policy for Jenkins EC2 instance to access ECR:
- `ecr:GetAuthorizationToken` - Login to ECR
- `ecr:PutImage` - Push images
- `ecr:BatchGetImage` - Pull images
- `ecr:StartImageScan` - Trigger scans
- `ecr:DescribeImageScanFindings` - View scan results

### 2. ecr-lifecycle-policy.json ✅

Lifecycle policy for automatic cleanup:
- Keep last 10 images
- Remove untagged images older than 7 days

### 3. scripts/setup-ecr.ps1 ✅

Automated PowerShell script that:
1. Creates ECR repository
2. Creates IAM policy
3. Attaches policy to Jenkins instance role
4. Applies lifecycle policy
5. Configures EKS node roles

### 4. ECR-QUICK-START.md ✅

Quick reference guide with:
- Prerequisites checklist
- Quick setup commands
- Manual setup steps
- Testing procedures
- Common commands
- Troubleshooting tips

### 5. ECR-MIGRATION-SUMMARY.md ✅

This file - summary of all changes.

---

## What You Need to Do

### Step 1: Create ECR Repository and Configure IAM

**Option A: Automated (Recommended)**
```powershell
# Run from project root
.\scripts\setup-ecr.ps1
```

**Option B: Manual**
```powershell
# Create ECR repository
aws ecr create-repository `
  --repository-name springboot-app `
  --region us-east-1 `
  --image-scanning-configuration scanOnPush=true `
  --encryption-configuration encryptionType=AES256

# Create IAM policy
aws iam create-policy `
  --policy-name JenkinsECRPolicy `
  --policy-document file://jenkins-ecr-policy.json

# Attach to Jenkins instance role (replace with your role name)
aws iam attach-role-policy `
  --role-name <jenkins-instance-role> `
  --policy-arn arn:aws:iam::<account-id>:policy/JenkinsECRPolicy
```

### Step 2: Install AWS CLI on Jenkins Server

SSH to Jenkins server:
```bash
ssh -i your-key.pem ubuntu@<jenkins-server-ip>

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

### Step 3: Test ECR Access from Jenkins

```bash
# Switch to jenkins user
sudo su - jenkins

# Test ECR login
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Should see: Login Succeeded
```

### Step 4: Configure EKS Nodes for ECR Access

```powershell
# Get node group
$NODE_GROUPS = aws eks list-nodegroups `
  --cluster-name my-eks-cluster `
  --region us-east-1 `
  --query "nodegroups[0]" `
  --output text

# Get node role
$NODE_ROLE_ARN = aws eks describe-nodegroup `
  --cluster-name my-eks-cluster `
  --nodegroup-name $NODE_GROUPS `
  --region us-east-1 `
  --query "nodegroup.nodeRole" `
  --output text

$NODE_ROLE_NAME = $NODE_ROLE_ARN.Split('/')[-1]

# Attach ECR read policy
aws iam attach-role-policy `
  --role-name $NODE_ROLE_NAME `
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
```

### Step 5: Commit and Push Changes

```bash
git add Jenkinsfile k8s/deployment.yaml jenkins-ecr-policy.json ecr-lifecycle-policy.json scripts/setup-ecr.ps1 ECR-QUICK-START.md ECR-MIGRATION-SUMMARY.md
git commit -m "Migrate from Docker Hub to AWS ECR"
git push origin main
```

### Step 6: Trigger Jenkins Pipeline

The pipeline will now:
1. Build the application
2. Run tests and SonarQube analysis
3. Build Docker image
4. Scan with Trivy
5. **Login to ECR** (new)
6. **Push to ECR** (instead of Docker Hub)
7. **Trigger ECR scan** (new)
8. Deploy to EKS from ECR
9. Backup artifacts to S3

---

## Benefits of ECR Migration

### 1. No Rate Limits ✅
Docker Hub has pull rate limits (100 pulls/6 hours for anonymous, 200 for free accounts). ECR has no such limits.

### 2. Better AWS Integration ✅
- Native integration with EKS, IAM, CloudWatch
- No need to manage separate credentials
- Automatic authentication via IAM roles

### 3. Enhanced Security ✅
- Private by default (no public exposure)
- IAM-based access control
- Encryption at rest (AES-256)
- Built-in vulnerability scanning
- Integration with AWS Security Hub

### 4. Cost-Effective ✅
- Pay only for storage used ($0.10/GB/month)
- No pull charges within same region
- Lifecycle policies for automatic cleanup

### 5. Better Performance ✅
- Same region as EKS (lower latency)
- No external network dependency
- Faster image pulls

### 6. Compliance ✅
- Data stays within AWS
- Meets regulatory requirements
- Audit logs via CloudTrail

---

## Removed Dependencies

### Jenkins Credentials
**No longer needed:**
- ❌ Docker Hub username/password
- ❌ `docker-credentials` in Jenkins

**Now using:**
- ✅ IAM role attached to Jenkins EC2 instance
- ✅ Automatic authentication via AWS CLI

### Kubernetes Secrets
**No longer needed:**
- ❌ `docker-registry-secret` in Kubernetes
- ❌ `imagePullSecrets` in deployment

**Now using:**
- ✅ IAM role attached to EKS node group
- ✅ Automatic ECR authentication

---

## Image Naming Convention

### Docker Hub (Old)
```
username/springboot-app:1.0.0
username/springboot-app:latest
```

### ECR (New)
```
<account-id>.dkr.ecr.us-east-1.amazonaws.com/springboot-app:1
<account-id>.dkr.ecr.us-east-1.amazonaws.com/springboot-app:latest
<account-id>.dkr.ecr.us-east-1.amazonaws.com/springboot-app:abc123
<account-id>.dkr.ecr.us-east-1.amazonaws.com/springboot-app:release-1
```

**Tags:**
- Build number (e.g., `1`, `2`, `3`)
- `latest` - Most recent build
- Git commit SHA (e.g., `abc123`)
- Release tags (e.g., `release-1`) - Only for main branch

---

## Monitoring and Maintenance

### View Images in ECR
```powershell
aws ecr list-images --repository-name springboot-app --region us-east-1
```

### View Scan Results
```powershell
aws ecr describe-image-scan-findings `
  --repository-name springboot-app `
  --image-id imageTag=latest `
  --region us-east-1
```

### Check Storage Usage
```powershell
aws ecr describe-repositories `
  --repository-names springboot-app `
  --region us-east-1 `
  --query "repositories[0].repositoryUri"
```

### Monitor Costs
- Go to AWS Cost Explorer
- Filter by service: ECR
- View storage and data transfer costs

---

## Rollback Plan

If you need to rollback to Docker Hub:

1. Revert Jenkinsfile changes
2. Revert k8s/deployment.yaml changes
3. Add back Docker Hub credentials to Jenkins
4. Add back imagePullSecrets to Kubernetes
5. Push to trigger pipeline

**Note:** Keep ECR repository for future use.

---

## Support and Documentation

- **Detailed Guide:** `ECR-JENKINS-SETUP.md`
- **Quick Reference:** `ECR-QUICK-START.md`
- **AWS ECR Docs:** https://docs.aws.amazon.com/ecr/
- **Jenkins Pipeline:** `Jenkinsfile`
- **IAM Policy:** `jenkins-ecr-policy.json`
- **Lifecycle Policy:** `ecr-lifecycle-policy.json`

---

## Summary

✅ **Jenkinsfile** - Updated with ECR authentication and push stages
✅ **deployment.yaml** - Updated with ECR image URI format
✅ **IAM Policies** - Created for Jenkins and EKS nodes
✅ **Lifecycle Policy** - Automatic cleanup of old images
✅ **Setup Script** - Automated PowerShell script for ECR setup
✅ **Documentation** - Complete guides and references

**Your CI/CD pipeline is now fully configured to use AWS ECR!** 🚀

**Next:** Run `.\scripts\setup-ecr.ps1` to create ECR repository and configure IAM permissions.
