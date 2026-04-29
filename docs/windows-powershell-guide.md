# Windows PowerShell Guide for CI/CD Setup

Complete PowerShell commands for Windows users setting up the CI/CD pipeline.

## Prerequisites

### 1. Install Required Tools

#### AWS CLI

```powershell
# Download and install AWS CLI
# Visit: https://aws.amazon.com/cli/
# Or use winget
winget install Amazon.AWSCLI

# Verify installation
aws --version
```

#### AWS PowerShell Module (Optional but Recommended)

```powershell
# Install AWS Tools for PowerShell
Install-Module -Name AWS.Tools.Installer -Force -AllowClobber

# Install specific modules
Install-AWSToolsModule AWS.Tools.S3,AWS.Tools.EC2,AWS.Tools.EKS,AWS.Tools.IdentityManagement -Force

# Verify installation
Get-Module -ListAvailable AWS.Tools.*
```

#### kubectl

```powershell
# Download kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Move to a directory in PATH
Move-Item kubectl.exe C:\Windows\System32\

# Verify
kubectl version --client
```

#### Helm

```powershell
# Using Chocolatey
choco install kubernetes-helm

# Or download manually from https://github.com/helm/helm/releases
# Extract and add to PATH

# Verify
helm version
```

### 2. Configure AWS Credentials

```powershell
# Configure AWS CLI
aws configure

# You'll be prompted for:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity

# Alternative: Set credentials using PowerShell module
Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY" -StoreAs default
Set-DefaultAWSRegion -Region us-east-1
```

## Infrastructure Setup

### 1. Create S3 Bucket for Artifacts

```powershell
# Set variables
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$bucketName = "my-artifacts-bucket-$timestamp"
$region = "us-east-1"

# Create S3 bucket
aws s3 mb "s3://$bucketName" --region $region

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

# Create lifecycle policy
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

aws s3api put-bucket-lifecycle-configuration `
  --bucket $bucketName `
  --lifecycle-configuration file://lifecycle-policy.json

Write-Host "`nBucket created successfully!" -ForegroundColor Green
Write-Host "Bucket Name: $bucketName" -ForegroundColor Cyan
Write-Host "Save this bucket name for later use!" -ForegroundColor Yellow

# Save bucket name to file for later reference
$bucketName | Out-File -FilePath bucket-name.txt
```

### 2. Create IAM Policy for Jenkins

```powershell
# Get your bucket name (if you saved it)
$bucketName = Get-Content bucket-name.txt

# Create IAM policy document
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

# Get policy ARN
$accountId = aws sts get-caller-identity --query Account --output text
$policyArn = "arn:aws:iam::${accountId}:policy/JenkinsEKSPolicy"

Write-Host "`nIAM Policy created successfully!" -ForegroundColor Green
Write-Host "Policy ARN: $policyArn" -ForegroundColor Cyan

# Save policy ARN for later
$policyArn | Out-File -FilePath policy-arn.txt
```

### 3. Create IAM Role for Jenkins EC2

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
  --assume-role-policy-document file://trust-policy.json `
  --description "Role for Jenkins EC2 instance"

# Attach policy to role
$policyArn = Get-Content policy-arn.txt
aws iam attach-role-policy `
  --role-name JenkinsEC2Role `
  --policy-arn $policyArn

# Create instance profile
aws iam create-instance-profile `
  --instance-profile-name JenkinsEC2Profile

# Add role to instance profile
aws iam add-role-to-instance-profile `
  --instance-profile-name JenkinsEC2Profile `
  --role-name JenkinsEC2Role

Write-Host "`nIAM Role and Instance Profile created!" -ForegroundColor Green
Write-Host "Instance Profile: JenkinsEC2Profile" -ForegroundColor Cyan
Write-Host "Attach this profile to your Jenkins EC2 instance" -ForegroundColor Yellow
```

### 4. Create Security Groups

```powershell
# Get default VPC ID
$vpcId = aws ec2 describe-vpcs `
  --filters "Name=isDefault,Values=true" `
  --query "Vpcs[0].VpcId" `
  --output text

Write-Host "Using VPC: $vpcId" -ForegroundColor Cyan

# Create Security Group for Jenkins
$jenkinsSecurityGroup = aws ec2 create-security-group `
  --group-name jenkins-sg `
  --description "Security group for Jenkins server" `
  --vpc-id $vpcId `
  --query "GroupId" `
  --output text

Write-Host "Jenkins Security Group created: $jenkinsSecurityGroup" -ForegroundColor Green

# Add inbound rules for Jenkins
aws ec2 authorize-security-group-ingress `
  --group-id $jenkinsSecurityGroup `
  --protocol tcp `
  --port 8080 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "Jenkins Web UI"

aws ec2 authorize-security-group-ingress `
  --group-id $jenkinsSecurityGroup `
  --protocol tcp `
  --port 50000 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "Jenkins Agent"

aws ec2 authorize-security-group-ingress `
  --group-id $jenkinsSecurityGroup `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "SSH"

# Create Security Group for SonarQube
$sonarSecurityGroup = aws ec2 create-security-group `
  --group-name sonarqube-sg `
  --description "Security group for SonarQube server" `
  --vpc-id $vpcId `
  --query "GroupId" `
  --output text

Write-Host "SonarQube Security Group created: $sonarSecurityGroup" -ForegroundColor Green

aws ec2 authorize-security-group-ingress `
  --group-id $sonarSecurityGroup `
  --protocol tcp `
  --port 9000 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "SonarQube Web UI"

aws ec2 authorize-security-group-ingress `
  --group-id $sonarSecurityGroup `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "SSH"

# Create Security Group for Nexus
$nexusSecurityGroup = aws ec2 create-security-group `
  --group-name nexus-sg `
  --description "Security group for Nexus server" `
  --vpc-id $vpcId `
  --query "GroupId" `
  --output text

Write-Host "Nexus Security Group created: $nexusSecurityGroup" -ForegroundColor Green

aws ec2 authorize-security-group-ingress `
  --group-id $nexusSecurityGroup `
  --protocol tcp `
  --port 8081 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "Nexus Web UI"

aws ec2 authorize-security-group-ingress `
  --group-id $nexusSecurityGroup `
  --protocol tcp `
  --port 8082 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "Nexus Docker Registry"

aws ec2 authorize-security-group-ingress `
  --group-id $nexusSecurityGroup `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0 `
  --group-rule-description "SSH"

# Save security group IDs
@{
    Jenkins = $jenkinsSecurityGroup
    SonarQube = $sonarSecurityGroup
    Nexus = $nexusSecurityGroup
} | ConvertTo-Json | Out-File -FilePath security-groups.json

Write-Host "`nAll security groups created successfully!" -ForegroundColor Green
```

### 5. Launch EC2 Instances

```powershell
# Load security groups
$securityGroups = Get-Content security-groups.json | ConvertFrom-Json

# Get latest Ubuntu 22.04 AMI
$amiId = aws ec2 describe-images `
  --owners 099720109477 `
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" `
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" `
  --output text

Write-Host "Using AMI: $amiId" -ForegroundColor Cyan

# Launch Jenkins instance
$jenkinsInstanceId = aws ec2 run-instances `
  --image-id $amiId `
  --instance-type t3.medium `
  --key-name YOUR_KEY_PAIR_NAME `
  --security-group-ids $securityGroups.Jenkins `
  --iam-instance-profile Name=JenkinsEC2Profile `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Jenkins-Server}]" `
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=50,VolumeType=gp3}" `
  --query "Instances[0].InstanceId" `
  --output text

Write-Host "Jenkins instance launched: $jenkinsInstanceId" -ForegroundColor Green

# Launch SonarQube instance
$sonarInstanceId = aws ec2 run-instances `
  --image-id $amiId `
  --instance-type t3.medium `
  --key-name YOUR_KEY_PAIR_NAME `
  --security-group-ids $securityGroups.SonarQube `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=SonarQube-Server}]" `
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=50,VolumeType=gp3}" `
  --query "Instances[0].InstanceId" `
  --output text

Write-Host "SonarQube instance launched: $sonarInstanceId" -ForegroundColor Green

# Launch Nexus instance
$nexusInstanceId = aws ec2 run-instances `
  --image-id $amiId `
  --instance-type t3.small `
  --key-name YOUR_KEY_PAIR_NAME `
  --security-group-ids $securityGroups.Nexus `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Nexus-Server}]" `
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=100,VolumeType=gp3}" `
  --query "Instances[0].InstanceId" `
  --output text

Write-Host "Nexus instance launched: $nexusInstanceId" -ForegroundColor Green

# Wait for instances to be running
Write-Host "`nWaiting for instances to start..." -ForegroundColor Yellow
aws ec2 wait instance-running --instance-ids $jenkinsInstanceId $sonarInstanceId $nexusInstanceId

# Get public IPs
$jenkinsIp = aws ec2 describe-instances `
  --instance-ids $jenkinsInstanceId `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text

$sonarIp = aws ec2 describe-instances `
  --instance-ids $sonarInstanceId `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text

$nexusIp = aws ec2 describe-instances `
  --instance-ids $nexusInstanceId `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "EC2 Instances Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nJenkins Server:" -ForegroundColor Yellow
Write-Host "  Instance ID: $jenkinsInstanceId"
Write-Host "  Public IP: $jenkinsIp"
Write-Host "  URL: http://${jenkinsIp}:8080"
Write-Host "`nSonarQube Server:" -ForegroundColor Yellow
Write-Host "  Instance ID: $sonarInstanceId"
Write-Host "  Public IP: $sonarIp"
Write-Host "  URL: http://${sonarIp}:9000"
Write-Host "`nNexus Server:" -ForegroundColor Yellow
Write-Host "  Instance ID: $nexusInstanceId"
Write-Host "  Public IP: $nexusIp"
Write-Host "  URL: http://${nexusIp}:8081"
Write-Host "`n========================================" -ForegroundColor Cyan

# Save instance information
@{
    Jenkins = @{
        InstanceId = $jenkinsInstanceId
        PublicIp = $jenkinsIp
        Url = "http://${jenkinsIp}:8080"
    }
    SonarQube = @{
        InstanceId = $sonarInstanceId
        PublicIp = $sonarIp
        Url = "http://${sonarIp}:9000"
    }
    Nexus = @{
        InstanceId = $nexusInstanceId
        PublicIp = $nexusIp
        Url = "http://${nexusIp}:8081"
    }
} | ConvertTo-Json | Out-File -FilePath instances.json

Write-Host "Instance information saved to instances.json" -ForegroundColor Green
```

## Connecting to EC2 Instances

### Using SSH from PowerShell

```powershell
# Load instance information
$instances = Get-Content instances.json | ConvertFrom-Json

# Connect to Jenkins
ssh -i path\to\your-key.pem ubuntu@$($instances.Jenkins.PublicIp)

# Connect to SonarQube
ssh -i path\to\your-key.pem ubuntu@$($instances.SonarQube.PublicIp)

# Connect to Nexus
ssh -i path\to\your-key.pem ubuntu@$($instances.Nexus.PublicIp)
```

### Using PuTTY (Windows)

1. Convert .pem to .ppk using PuTTYgen
2. Open PuTTY
3. Enter hostname: `ubuntu@<instance-ip>`
4. Connection → SSH → Auth → Browse for .ppk file
5. Click Open

## Useful PowerShell Commands

### Check AWS Resources

```powershell
# List S3 buckets
aws s3 ls

# List EC2 instances
aws ec2 describe-instances `
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" `
  --output table

# List IAM policies
aws iam list-policies --scope Local --query "Policies[*].[PolicyName,Arn]" --output table

# List security groups
aws ec2 describe-security-groups `
  --query "SecurityGroups[*].[GroupId,GroupName,Description]" `
  --output table
```

### Manage EC2 Instances

```powershell
# Stop instances
aws ec2 stop-instances --instance-ids $jenkinsInstanceId $sonarInstanceId $nexusInstanceId

# Start instances
aws ec2 start-instances --instance-ids $jenkinsInstanceId $sonarInstanceId $nexusInstanceId

# Terminate instances (careful!)
aws ec2 terminate-instances --instance-ids $jenkinsInstanceId $sonarInstanceId $nexusInstanceId
```

### Clean Up Resources

```powershell
# Delete S3 bucket (must be empty first)
aws s3 rm "s3://$bucketName" --recursive
aws s3 rb "s3://$bucketName"

# Delete security groups
aws ec2 delete-security-group --group-id $jenkinsSecurityGroup
aws ec2 delete-security-group --group-id $sonarSecurityGroup
aws ec2 delete-security-group --group-id $nexusSecurityGroup

# Detach and delete IAM policy
aws iam detach-role-policy --role-name JenkinsEC2Role --policy-arn $policyArn
aws iam remove-role-from-instance-profile --instance-profile-name JenkinsEC2Profile --role-name JenkinsEC2Role
aws iam delete-instance-profile --instance-profile-name JenkinsEC2Profile
aws iam delete-role --role-name JenkinsEC2Role
aws iam delete-policy --policy-arn $policyArn
```

## Troubleshooting

### AWS CLI Not Found

```powershell
# Check if AWS CLI is in PATH
$env:Path -split ';' | Select-String -Pattern 'aws'

# Add to PATH if needed
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
```

### Permission Denied Errors

```powershell
# Run PowerShell as Administrator
Start-Process powershell -Verb RunAs

# Or check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### JSON Formatting Issues

```powershell
# Use here-strings for multi-line JSON
$json = @"
{
  "key": "value"
}
"@

# Or use ConvertTo-Json
$object = @{key = "value"}
$json = $object | ConvertTo-Json
```

## Next Steps

After infrastructure is set up:
1. Follow [Jenkins Setup](02-jenkins-setup.md) - SSH to Jenkins server
2. Follow [SonarQube Setup](03-sonarqube-setup.md) - SSH to SonarQube server
3. Follow [Nexus Setup](04-nexus-setup.md) - SSH to Nexus server

## Additional Resources

- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/)
- [AWS Tools for PowerShell](https://aws.amazon.com/powershell/)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
