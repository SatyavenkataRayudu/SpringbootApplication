# ECR Setup Script for Windows PowerShell
# This script creates and configures AWS ECR repository for the Spring Boot application

# Variables
$AWS_REGION = "us-east-1"
$REPO_NAME = "springboot-app"
$JENKINS_INSTANCE_NAME = "Jenkins-Server"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AWS ECR Setup for Spring Boot App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get AWS Account ID
Write-Host "Getting AWS Account ID..." -ForegroundColor Yellow
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get AWS Account ID. Make sure AWS CLI is configured." -ForegroundColor Red
    exit 1
}
Write-Host "AWS Account ID: $ACCOUNT_ID" -ForegroundColor Green
Write-Host ""

# Step 1: Create ECR Repository
Write-Host "Step 1: Creating ECR Repository..." -ForegroundColor Yellow
$repoExists = aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ECR repository '$REPO_NAME' already exists." -ForegroundColor Yellow
} else {
    aws ecr create-repository `
        --repository-name $REPO_NAME `
        --region $AWS_REGION `
        --image-scanning-configuration scanOnPush=true `
        --encryption-configuration encryptionType=AES256
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ECR repository created successfully!" -ForegroundColor Green
    } else {
        Write-Host "Error: Failed to create ECR repository." -ForegroundColor Red
        exit 1
    }
}

# Get ECR URI
$ECR_URI = aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION --query "repositories[0].repositoryUri" --output text
Write-Host "ECR Repository URI: $ECR_URI" -ForegroundColor Green
Write-Host ""

# Step 2: Create IAM Policy for Jenkins
Write-Host "Step 2: Creating IAM Policy for Jenkins ECR Access..." -ForegroundColor Yellow
$policyExists = aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/JenkinsECRPolicy" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "IAM policy 'JenkinsECRPolicy' already exists." -ForegroundColor Yellow
} else {
    aws iam create-policy `
        --policy-name JenkinsECRPolicy `
        --policy-document file://jenkins-ecr-policy.json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "IAM policy created successfully!" -ForegroundColor Green
    } else {
        Write-Host "Error: Failed to create IAM policy." -ForegroundColor Red
        exit 1
    }
}
$POLICY_ARN = "arn:aws:iam::${ACCOUNT_ID}:policy/JenkinsECRPolicy"
Write-Host "Policy ARN: $POLICY_ARN" -ForegroundColor Green
Write-Host ""

# Step 3: Get Jenkins Instance ID
Write-Host "Step 3: Finding Jenkins EC2 Instance..." -ForegroundColor Yellow
$JENKINS_INSTANCE_ID = aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=$JENKINS_INSTANCE_NAME" "Name=instance-state-name,Values=running" `
    --query "Reservations[0].Instances[0].InstanceId" `
    --output text

if ($JENKINS_INSTANCE_ID -eq "None" -or $JENKINS_INSTANCE_ID -eq "") {
    Write-Host "Error: Jenkins instance not found. Make sure it's running and tagged as '$JENKINS_INSTANCE_NAME'" -ForegroundColor Red
    Write-Host "You can manually attach the policy to the Jenkins instance role later." -ForegroundColor Yellow
} else {
    Write-Host "Jenkins Instance ID: $JENKINS_INSTANCE_ID" -ForegroundColor Green
    
    # Get Instance Profile ARN
    $INSTANCE_PROFILE_ARN = aws ec2 describe-instances `
        --instance-ids $JENKINS_INSTANCE_ID `
        --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" `
        --output text
    
    if ($INSTANCE_PROFILE_ARN -ne "None" -and $INSTANCE_PROFILE_ARN -ne "") {
        # Extract role name from instance profile
        $ROLE_NAME = $INSTANCE_PROFILE_ARN.Split('/')[-1]
        Write-Host "Jenkins IAM Role: $ROLE_NAME" -ForegroundColor Green
        
        # Attach policy to role
        Write-Host "Attaching ECR policy to Jenkins role..." -ForegroundColor Yellow
        aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Policy attached successfully!" -ForegroundColor Green
        } else {
            Write-Host "Error: Failed to attach policy to role." -ForegroundColor Red
        }
    } else {
        Write-Host "Warning: Jenkins instance doesn't have an IAM role attached." -ForegroundColor Yellow
        Write-Host "You need to create and attach an IAM role to the Jenkins instance." -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 4: Apply Lifecycle Policy
Write-Host "Step 4: Applying ECR Lifecycle Policy..." -ForegroundColor Yellow
aws ecr put-lifecycle-policy `
    --repository-name $REPO_NAME `
    --lifecycle-policy-text file://ecr-lifecycle-policy.json `
    --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-Host "Lifecycle policy applied successfully!" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to apply lifecycle policy." -ForegroundColor Red
}
Write-Host ""

# Step 5: Configure EKS Node Role for ECR Access
Write-Host "Step 5: Configuring EKS Node Role for ECR Access..." -ForegroundColor Yellow
$EKS_CLUSTER_NAME = "my-eks-cluster"

# Get node group names
$NODE_GROUPS = aws eks list-nodegroups --cluster-name $EKS_CLUSTER_NAME --region $AWS_REGION --query "nodegroups" --output text

if ($NODE_GROUPS) {
    $NODE_GROUP_ARRAY = $NODE_GROUPS -split "`t"
    foreach ($NODE_GROUP in $NODE_GROUP_ARRAY) {
        Write-Host "Processing node group: $NODE_GROUP" -ForegroundColor Cyan
        
        # Get node role ARN
        $NODE_ROLE_ARN = aws eks describe-nodegroup `
            --cluster-name $EKS_CLUSTER_NAME `
            --nodegroup-name $NODE_GROUP `
            --region $AWS_REGION `
            --query "nodegroup.nodeRole" `
            --output text
        
        if ($NODE_ROLE_ARN) {
            $NODE_ROLE_NAME = $NODE_ROLE_ARN.Split('/')[-1]
            Write-Host "Node Role: $NODE_ROLE_NAME" -ForegroundColor Green
            
            # Attach ECR read policy
            aws iam attach-role-policy `
                --role-name $NODE_ROLE_NAME `
                --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "ECR read policy attached to node role!" -ForegroundColor Green
            } else {
                Write-Host "Policy might already be attached or error occurred." -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "Warning: No node groups found for EKS cluster." -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ECR Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  ECR Repository URI: $ECR_URI" -ForegroundColor White
Write-Host "  AWS Account ID: $ACCOUNT_ID" -ForegroundColor White
Write-Host "  AWS Region: $AWS_REGION" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. SSH to Jenkins server and install AWS CLI (if not installed)" -ForegroundColor White
Write-Host "  2. Test ECR login from Jenkins server:" -ForegroundColor White
Write-Host "     aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI" -ForegroundColor Cyan
Write-Host "  3. Update Jenkinsfile (already done)" -ForegroundColor White
Write-Host "  4. Update k8s/deployment.yaml (already done)" -ForegroundColor White
Write-Host "  5. Commit and push changes to trigger Jenkins pipeline" -ForegroundColor White
Write-Host ""
