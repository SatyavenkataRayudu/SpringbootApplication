# Infrastructure Setup

> **Important**: This guide assumes you're setting up **3 separate EC2 instances** (one for Jenkins, one for SonarQube, one for Nexus). See [Architecture Overview](00-architecture-overview.md) for details and alternative combined server setup.

> **Windows Users**: See the [Windows PowerShell Guide](windows-powershell-guide.md) for complete PowerShell commands for all steps in this guide.

## Server Sizing Overview

### Tool-Specific Requirements

Each tool in the CI/CD pipeline has different resource requirements. **Do not use identical servers** for cost optimization and performance.

| Tool | Instance Type | vCPU | RAM | Storage | Primary Resource |
|------|---------------|------|-----|---------|------------------|
| Jenkins | t3.medium - t3.large | 2-4 | 4-8GB | 50-100GB | CPU (builds) |
| SonarQube | t3.medium | 2 | 4GB | 50GB | Memory (analysis) |
| Nexus | t3.small - t3.medium | 2 | 2-4GB | 100-500GB | Storage/I/O |

### Deployment Strategies

**Option 1: Separate Servers (Recommended for Production)**
- Total: 3 EC2 instances
- Cost: ~$150-200/month
- Benefits:
  - Better isolation and security
  - Independent scaling
  - No resource contention
  - Easier troubleshooting
  - Production-grade reliability

**Option 2: Combined Server (Dev/Test Only)**
- Total: 1 EC2 instance (t3.large: 2 vCPU, 8GB RAM)
- Cost: ~$60-70/month
- Benefits:
  - Lower cost for development
  - Simpler management
  - Good for learning/testing
- Drawbacks:
  - Resource contention during builds
  - Single point of failure
  - Not suitable for production

**Option 3: Hybrid Approach**
- Jenkins: Separate t3.medium
- SonarQube + Nexus: Shared t3.medium
- Cost: ~$100-120/month
- Balanced approach for small teams

### Why Different Sizes Matter

1. **Jenkins** - CPU intensive:
   - Compiles code
   - Runs tests
   - Builds Docker images
   - Executes multiple pipelines

2. **SonarQube** - Memory intensive:
   - Runs Elasticsearch
   - Analyzes code quality
   - Maintains analysis history
   - Requires kernel tuning

3. **Nexus** - Storage intensive:
   - Stores artifacts and images
   - Serves downloads
   - Less compute needed
   - Storage grows over time

## Prerequisites

### 1. Install Required Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)

# Verify configuration
aws sts get-caller-identity
```

### 3. Create S3 Bucket for Artifacts

#### Using Bash (Linux/Mac/WSL)

```bash
# Create S3 bucket
aws s3 mb s3://my-artifacts-bucket-$(date +%s) --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-artifacts-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket my-artifacts-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Set lifecycle policy
cat > lifecycle-policy.json <<EOF
{
  "Rules": [{
    "Id": "DeleteOldArtifacts",
    "Status": "Enabled",
    "Prefix": "artifacts/",
    "Expiration": {
      "Days": 90
    }
  }]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket my-artifacts-bucket \
  --lifecycle-configuration file://lifecycle-policy.json
```

#### Using PowerShell (Windows)

```powershell
# Create S3 bucket with timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$bucketName = "my-artifacts-bucket-$timestamp"

aws s3 mb "s3://$bucketName" --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning `
  --bucket $bucketName `
  --versioning-configuration Status=Enabled

# Enable encryption
$encryptionConfig = @"
{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": {
      "SSEAlgorithm": "AES256"
    }
  }]
}
"@

aws s3api put-bucket-encryption `
  --bucket $bucketName `
  --server-side-encryption-configuration $encryptionConfig

# Create lifecycle policy file
$lifecyclePolicy = @"
{
  "Rules": [{
    "Id": "DeleteOldArtifacts",
    "Status": "Enabled",
    "Prefix": "artifacts/",
    "Expiration": {
      "Days": 90
    }
  }]
}
"@

$lifecyclePolicy | Out-File -FilePath lifecycle-policy.json -Encoding utf8

# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration `
  --bucket $bucketName `
  --lifecycle-configuration file://lifecycle-policy.json

# Display bucket name for reference
Write-Host "Bucket created: $bucketName" -ForegroundColor Green
Write-Host "Save this bucket name for later use!" -ForegroundColor Yellow
```

#### Alternative: Using AWS PowerShell Module

```powershell
# Install AWS PowerShell module (if not already installed)
Install-Module -Name AWS.Tools.S3 -Force -AllowClobber

# Import module
Import-Module AWS.Tools.S3

# Set AWS credentials (if not using AWS CLI)
Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY" -StoreAs default
Set-DefaultAWSRegion -Region us-east-1

# Create S3 bucket
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$bucketName = "my-artifacts-bucket-$timestamp"

New-S3Bucket -BucketName $bucketName -Region us-east-1

# Enable versioning
Write-S3BucketVersioning -BucketName $bucketName -VersioningConfig_Status Enabled

# Enable encryption
$encryptionRule = New-Object Amazon.S3.Model.ServerSideEncryptionRule
$encryptionRule.ServerSideEncryptionByDefault = New-Object Amazon.S3.Model.ServerSideEncryptionByDefault
$encryptionRule.ServerSideEncryptionByDefault.ServerSideEncryptionAlgorithm = "AES256"

$encryptionConfig = New-Object Amazon.S3.Model.ServerSideEncryptionConfiguration
$encryptionConfig.ServerSideEncryptionRules.Add($encryptionRule)

Set-S3BucketEncryption -BucketName $bucketName -ServerSideEncryptionConfiguration $encryptionConfig

# Set lifecycle policy
$lifecycleRule = New-Object Amazon.S3.Model.LifecycleRule
$lifecycleRule.Id = "DeleteOldArtifacts"
$lifecycleRule.Status = "Enabled"
$lifecycleRule.Filter = New-Object Amazon.S3.Model.LifecycleRuleFilter
$lifecycleRule.Filter.LifecycleFilterPredicate = New-Object Amazon.S3.Model.LifecyclePrefixPredicate
$lifecycleRule.Filter.LifecycleFilterPredicate.Prefix = "artifacts/"
$lifecycleRule.Expiration = New-Object Amazon.S3.Model.LifecycleRuleExpiration
$lifecycleRule.Expiration.Days = 90

$lifecycleConfig = New-Object Amazon.S3.Model.LifecycleConfiguration
$lifecycleConfig.Rules.Add($lifecycleRule)

Write-S3LifecycleConfiguration -BucketName $bucketName -Configuration $lifecycleConfig

Write-Host "Bucket created successfully: $bucketName" -ForegroundColor Green
Write-Host "Versioning: Enabled" -ForegroundColor Green
Write-Host "Encryption: AES256" -ForegroundColor Green
Write-Host "Lifecycle: Delete artifacts older than 90 days" -ForegroundColor Green
```

#### Verify Bucket Creation

**Bash:**
```bash
# List buckets
aws s3 ls

# Check bucket details
aws s3api get-bucket-versioning --bucket my-artifacts-bucket
aws s3api get-bucket-encryption --bucket my-artifacts-bucket
```

**PowerShell:**
```powershell
# List buckets
aws s3 ls

# Or using PowerShell module
Get-S3Bucket

# Check bucket details
aws s3api get-bucket-versioning --bucket $bucketName
aws s3api get-bucket-encryption --bucket $bucketName

# Or using PowerShell module
Get-S3BucketVersioning -BucketName $bucketName
Get-S3BucketEncryption -BucketName $bucketName
```

### 4. Create IAM Roles and Policies

#### Using Bash (Linux/Mac/WSL)

```bash
# Create IAM policy for Jenkins
cat > jenkins-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-artifacts-bucket",
        "arn:aws:s3:::my-artifacts-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name JenkinsEKSPolicy \
  --policy-document file://jenkins-policy.json
```

#### Using PowerShell (Windows)

```powershell
# Create IAM policy for Jenkins
$policyDocument = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$bucketName",
        "arn:aws:s3:::$bucketName/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
"@

# Save policy to file
$policyDocument | Out-File -FilePath jenkins-policy.json -Encoding utf8

# Create IAM policy
aws iam create-policy `
  --policy-name JenkinsEKSPolicy `
  --policy-document file://jenkins-policy.json

# Display policy ARN
$accountId = aws sts get-caller-identity --query Account --output text
$policyArn = "arn:aws:iam::${accountId}:policy/JenkinsEKSPolicy"
Write-Host "Policy created: $policyArn" -ForegroundColor Green
```

#### Alternative: Using AWS PowerShell Module

```powershell
# Import IAM module
Import-Module AWS.Tools.IdentityManagement

# Create policy document
$policyDocument = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "eks:DescribeCluster",
                "eks:ListClusters"
            )
            Resource = "*"
        },
        @{
            Effect = "Allow"
            Action = @(
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket"
            )
            Resource = @(
                "arn:aws:s3:::$bucketName",
                "arn:aws:s3:::$bucketName/*"
            )
        },
        @{
            Effect = "Allow"
            Action = @(
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            )
            Resource = "*"
        }
    )
} | ConvertTo-Json -Depth 10

# Create IAM policy
$policy = New-IAMPolicy `
    -PolicyName "JenkinsEKSPolicy" `
    -PolicyDocument $policyDocument `
    -Description "Policy for Jenkins to access EKS, S3, and ECR"

Write-Host "Policy created successfully!" -ForegroundColor Green
Write-Host "Policy ARN: $($policy.Arn)" -ForegroundColor Cyan
```

#### Create IAM Role and Attach Policy

**PowerShell:**
```powershell
# Create trust policy for EC2
$trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

$trustPolicy | Out-File -FilePath trust-policy.json -Encoding utf8

# Create IAM role
aws iam create-role `
  --role-name JenkinsEC2Role `
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
$accountId = aws sts get-caller-identity --query Account --output text
aws iam attach-role-policy `
  --role-name JenkinsEC2Role `
  --policy-arn "arn:aws:iam::${accountId}:policy/JenkinsEKSPolicy"

# Create instance profile
aws iam create-instance-profile --instance-profile-name JenkinsEC2Profile

# Add role to instance profile
aws iam add-role-to-instance-profile `
  --instance-profile-name JenkinsEC2Profile `
  --role-name JenkinsEC2Role

Write-Host "IAM Role and Instance Profile created successfully!" -ForegroundColor Green
Write-Host "Attach 'JenkinsEC2Profile' to your Jenkins EC2 instance" -ForegroundColor Yellow
```

## Security Considerations

### Authentication Strategy

Before proceeding with tool installation, plan your authentication strategy:

**For Enterprise/Production:**
- LDAP/Active Directory integration (recommended)
- OAuth 2.0 / SAML SSO
- Centralized user management
- Group-based access control

**For Development/Small Teams:**
- Local users with strong passwords
- API tokens for automation
- Manual user management

See [Authentication Integration Guide](docs/07-authentication-integration.md) for detailed setup after tool installation.

### Network Security

```bash
# Security Group Rules (AWS)
# Jenkins: 8080, 50000
# SonarQube: 9000
# Nexus: 8081, 8082
# SSH: 22 (restricted IPs only)

# Use HTTPS in production
# Configure VPC and private subnets
# Enable AWS Security Groups
# Use IAM roles instead of access keys where possible
```

## Next Steps

Proceed to [Jenkins Configuration](02-jenkins-setup.md)
