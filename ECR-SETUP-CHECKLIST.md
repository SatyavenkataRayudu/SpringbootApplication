# ECR Setup Checklist

Complete checklist for migrating from Docker Hub to AWS ECR.

---

## Pre-Setup Verification

- [ ] AWS CLI installed on your Windows machine
- [ ] AWS CLI configured with proper credentials
- [ ] Jenkins server running on EC2 (Ubuntu)
- [ ] Docker installed on Jenkins server
- [ ] EKS cluster created (`my-eks-cluster`)
- [ ] S3 bucket exists (`my-artifacts-bucket-20260427170349`)
- [ ] You have IAM permissions to create policies and attach roles

---

## Step 1: Create ECR Repository (PowerShell)

### Option A: Automated Setup (Recommended)

```powershell
# Navigate to project directory
cd C:\Users\bhava\OneDrive\Desktop\KIRO\EKS-Deploy-App-CICD-GitHub-Maven-Jenkins-Trivy-Docker-Nexus-AWS-S3-SonarQube

# Run setup script
.\scripts\setup-ecr.ps1
```

**What it does:**
- ✅ Creates ECR repository `springboot-app`
- ✅ Creates IAM policy `JenkinsECRPolicy`
- ✅ Attaches policy to Jenkins EC2 instance role
- ✅ Applies lifecycle policy for cleanup
- ✅ Configures EKS node roles for ECR access

**Checklist:**
- [ ] Script completed without errors
- [ ] ECR repository URI displayed
- [ ] IAM policy created
- [ ] Policy attached to Jenkins role
- [ ] Lifecycle policy applied
- [ ] EKS node roles configured

### Option B: Manual Setup

If automated script fails, follow manual steps in `ECR-QUICK-START.md`.

---

## Step 2: Install AWS CLI on Jenkins Server

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@<jenkins-server-public-ip>

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
# Should show: aws-cli/2.x.x

# Test IAM role access
aws sts get-caller-identity
# Should show your account ID and role

# Test ECR access
aws ecr describe-repositories --region us-east-1
# Should list repositories including springboot-app
```

**Checklist:**
- [ ] AWS CLI installed successfully
- [ ] `aws --version` shows version 2.x
- [ ] `aws sts get-caller-identity` returns account info
- [ ] `aws ecr describe-repositories` lists springboot-app

---

## Step 3: Test ECR Login from Jenkins Server

```bash
# Switch to jenkins user
sudo su - jenkins

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Test ECR login
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Should see: Login Succeeded
```

**Checklist:**
- [ ] Account ID retrieved successfully
- [ ] ECR login succeeded
- [ ] No authentication errors

**If login fails:**
- Check IAM role is attached to Jenkins instance
- Verify IAM policy has `ecr:GetAuthorizationToken` permission
- Check AWS CLI is configured correctly

---

## Step 4: Verify Jenkins IAM Role

```powershell
# Get Jenkins instance ID
$JENKINS_INSTANCE_ID = aws ec2 describe-instances `
  --filters "Name=tag:Name,Values=Jenkins-Server" "Name=instance-state-name,Values=running" `
  --query "Reservations[0].Instances[0].InstanceId" `
  --output text

echo "Jenkins Instance ID: $JENKINS_INSTANCE_ID"

# Check IAM role
$INSTANCE_PROFILE = aws ec2 describe-instances `
  --instance-ids $JENKINS_INSTANCE_ID `
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" `
  --output text

echo "Instance Profile: $INSTANCE_PROFILE"

# Get role name
$ROLE_NAME = $INSTANCE_PROFILE.Split('/')[-1]

# List attached policies
aws iam list-attached-role-policies --role-name $ROLE_NAME
```

**Checklist:**
- [ ] Jenkins instance has IAM role attached
- [ ] `JenkinsECRPolicy` is in the list of attached policies
- [ ] Role has necessary ECR permissions

---

## Step 5: Verify EKS Node Role

```powershell
# Get node groups
$NODE_GROUPS = aws eks list-nodegroups `
  --cluster-name my-eks-cluster `
  --region us-east-1 `
  --query "nodegroups" `
  --output text

echo "Node Groups: $NODE_GROUPS"

# For each node group, check role
$NODE_GROUP_ARRAY = $NODE_GROUPS -split "`t"
foreach ($NODE_GROUP in $NODE_GROUP_ARRAY) {
    echo "Checking node group: $NODE_GROUP"
    
    $NODE_ROLE_ARN = aws eks describe-nodegroup `
        --cluster-name my-eks-cluster `
        --nodegroup-name $NODE_GROUP `
        --region us-east-1 `
        --query "nodegroup.nodeRole" `
        --output text
    
    $NODE_ROLE_NAME = $NODE_ROLE_ARN.Split('/')[-1]
    
    echo "Node Role: $NODE_ROLE_NAME"
    
    # Check policies
    aws iam list-attached-role-policies --role-name $NODE_ROLE_NAME
}
```

**Checklist:**
- [ ] EKS node groups found
- [ ] Each node group has IAM role
- [ ] `AmazonEC2ContainerRegistryReadOnly` policy is attached
- [ ] Nodes can pull from ECR

---

## Step 6: Verify ECR Repository Configuration

```powershell
# Check repository exists
aws ecr describe-repositories `
  --repository-names springboot-app `
  --region us-east-1

# Check image scanning is enabled
aws ecr describe-repositories `
  --repository-names springboot-app `
  --region us-east-1 `
  --query "repositories[0].imageScanningConfiguration"
# Should show: {"scanOnPush": true}

# Check encryption
aws ecr describe-repositories `
  --repository-names springboot-app `
  --region us-east-1 `
  --query "repositories[0].encryptionConfiguration"
# Should show: {"encryptionType": "AES256"}

# Check lifecycle policy
aws ecr get-lifecycle-policy `
  --repository-name springboot-app `
  --region us-east-1
```

**Checklist:**
- [ ] Repository exists
- [ ] Image scanning enabled (`scanOnPush: true`)
- [ ] Encryption enabled (`AES256`)
- [ ] Lifecycle policy applied

---

## Step 7: Verify File Changes

```powershell
# Check Jenkinsfile
cat Jenkinsfile | Select-String "ECR_REGISTRY"
# Should show ECR_REGISTRY variable

# Check deployment.yaml
cat k8s/deployment.yaml | Select-String "IMAGE_URI"
# Should show IMAGE_URI:IMAGE_TAG

# Check no imagePullSecrets
cat k8s/deployment.yaml | Select-String "imagePullSecrets"
# Should show comment about not needing it
```

**Checklist:**
- [ ] Jenkinsfile has ECR variables
- [ ] Jenkinsfile has ECR Login stage
- [ ] Jenkinsfile has Push to ECR stage
- [ ] Jenkinsfile has ECR Image Scan stage
- [ ] deployment.yaml uses IMAGE_URI:IMAGE_TAG
- [ ] deployment.yaml has no imagePullSecrets

---

## Step 8: Configure Jenkins (If Not Done)

### Install Required Plugins

Jenkins → Manage Jenkins → Manage Plugins → Available

- [ ] Pipeline
- [ ] Git
- [ ] Docker Pipeline
- [ ] AWS Steps
- [ ] SonarQube Scanner
- [ ] JaCoCo

### Configure Tools

Jenkins → Manage Jenkins → Global Tool Configuration

**Maven:**
- [ ] Name: `Maven-3.9`
- [ ] Version: 3.9.x
- [ ] Install automatically: ✅

**JDK:**
- [ ] Name: `JDK-17`
- [ ] Version: 17
- [ ] Install automatically: ✅

**SonarQube Scanner:**
- [ ] Name: `SonarQube Scanner`
- [ ] Version: Latest
- [ ] Install automatically: ✅

### Configure Credentials

Jenkins → Manage Jenkins → Manage Credentials → Global

**Required Credentials:**

1. **GitHub Credentials**
   - [ ] ID: `github-credentials`
   - [ ] Type: Username with password
   - [ ] Username: Your GitHub username
   - [ ] Password: GitHub personal access token

2. **SonarQube Token**
   - [ ] ID: `sonarqube-token`
   - [ ] Type: Secret text
   - [ ] Secret: SonarQube authentication token

3. **Nexus Credentials**
   - [ ] ID: `nexus-credentials`
   - [ ] Type: Username with password
   - [ ] Username: admin
   - [ ] Password: Nexus admin password

**NOT NEEDED (Removed):**
- ❌ Docker Hub credentials (using ECR with IAM now)

### Configure SonarQube Server

Jenkins → Manage Jenkins → Configure System → SonarQube servers

- [ ] Name: `SonarQube`
- [ ] Server URL: `http://<sonarqube-server-ip>:9000`
- [ ] Server authentication token: Select `sonarqube-token`

---

## Step 9: Create Jenkins Pipeline Job

1. **Create New Item**
   - [ ] Name: `springboot-app-pipeline`
   - [ ] Type: Pipeline
   - [ ] Click OK

2. **Configure Pipeline**
   - [ ] Description: "Spring Boot CI/CD Pipeline with ECR"
   - [ ] GitHub project: ✅
   - [ ] Project URL: Your GitHub repo URL

3. **Build Triggers**
   - [ ] GitHub hook trigger for GITScm polling: ✅

4. **Pipeline Definition**
   - [ ] Definition: Pipeline script from SCM
   - [ ] SCM: Git
   - [ ] Repository URL: Your GitHub repo URL
   - [ ] Credentials: Select `github-credentials`
   - [ ] Branch: `*/main`
   - [ ] Script Path: `Jenkinsfile`

5. **Save**

---

## Step 10: Test Manual Build

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@<jenkins-server-ip>

# Switch to jenkins user
sudo su - jenkins

# Clone your repo
cd /tmp
git clone <your-repo-url>
cd <repo-name>

# Test Maven build
mvn clean package -DskipTests

# Test Docker build
docker build -t test:1.0 .

# Test ECR push
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

docker tag test:1.0 ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test

# Verify in ECR
aws ecr list-images --repository-name springboot-app --region us-east-1
```

**Checklist:**
- [ ] Maven build succeeds
- [ ] Docker build succeeds
- [ ] ECR login succeeds
- [ ] Image push to ECR succeeds
- [ ] Image appears in ECR repository

---

## Step 11: Commit and Push Changes

```powershell
# Check status
git status

# Add files
git add Jenkinsfile
git add k8s/deployment.yaml
git add jenkins-ecr-policy.json
git add ecr-lifecycle-policy.json
git add scripts/setup-ecr.ps1
git add ECR-JENKINS-SETUP.md
git add ECR-QUICK-START.md
git add ECR-MIGRATION-SUMMARY.md
git add ECR-SETUP-CHECKLIST.md

# Commit
git commit -m "Migrate from Docker Hub to AWS ECR

- Updated Jenkinsfile with ECR authentication and push stages
- Updated k8s/deployment.yaml to use ECR image URI
- Added IAM policies for Jenkins and EKS nodes
- Added lifecycle policy for automatic cleanup
- Added ECR setup scripts and documentation
- Removed Docker Hub dependencies"

# Push
git push origin main
```

**Checklist:**
- [ ] All files committed
- [ ] Changes pushed to GitHub
- [ ] GitHub shows latest commit

---

## Step 12: Trigger Jenkins Pipeline

### Option A: Manual Trigger

1. Go to Jenkins: `http://<jenkins-server-ip>:8080`
2. Click on `springboot-app-pipeline`
3. Click "Build Now"
4. Watch console output

### Option B: GitHub Webhook (Automatic)

1. Go to GitHub repo → Settings → Webhooks
2. Add webhook:
   - Payload URL: `http://<jenkins-server-ip>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event
   - Active: ✅
3. Push a commit to trigger automatically

**Checklist:**
- [ ] Pipeline triggered
- [ ] All stages pass
- [ ] ECR Login stage succeeds
- [ ] Push to ECR stage succeeds
- [ ] ECR Image Scan stage succeeds
- [ ] Deploy to EKS stage succeeds

---

## Step 13: Verify Deployment

```powershell
# Update kubeconfig
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1

# Check namespace
kubectl get namespace production

# Check pods
kubectl get pods -n production

# Check deployment
kubectl get deployment springboot-app -n production

# Check service
kubectl get service springboot-app -n production

# Check pod details (verify ECR image)
kubectl describe pod -n production -l app=springboot-app | Select-String "Image:"
# Should show ECR URI

# Check logs
kubectl logs -n production -l app=springboot-app --tail=50
```

**Checklist:**
- [ ] Namespace exists
- [ ] Pods are running
- [ ] Deployment is healthy
- [ ] Service is created
- [ ] Pods are using ECR image
- [ ] Application logs show no errors

---

## Step 14: Verify ECR Images

```powershell
# List images
aws ecr list-images --repository-name springboot-app --region us-east-1

# Describe specific image
aws ecr describe-images `
  --repository-name springboot-app `
  --region us-east-1 `
  --image-ids imageTag=latest

# Check scan results
aws ecr describe-image-scan-findings `
  --repository-name springboot-app `
  --image-id imageTag=latest `
  --region us-east-1
```

**Checklist:**
- [ ] Images appear in ECR
- [ ] Multiple tags present (build number, latest, git commit)
- [ ] Image scan completed
- [ ] Scan findings reviewed

---

## Step 15: Test Application

```powershell
# Get service endpoint
kubectl get service springboot-app -n production

# If using LoadBalancer
$LB_URL = kubectl get service springboot-app -n production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo "Application URL: http://$LB_URL:8080"

# Test health endpoint
curl http://$LB_URL:8080/actuator/health

# Test S3 endpoint
curl http://$LB_URL:8080/api/s3/files
```

**Checklist:**
- [ ] Service endpoint accessible
- [ ] Health check returns OK
- [ ] S3 integration working
- [ ] Application responds correctly

---

## Troubleshooting

### ECR Login Fails on Jenkins

**Problem:** `aws ecr get-login-password` fails

**Solutions:**
- [ ] Check IAM role attached to Jenkins instance
- [ ] Verify `JenkinsECRPolicy` is attached to role
- [ ] Check AWS CLI is installed: `aws --version`
- [ ] Test: `aws sts get-caller-identity`

### Image Push Fails

**Problem:** `docker push` to ECR fails

**Solutions:**
- [ ] Check ECR repository exists
- [ ] Verify IAM policy has `ecr:PutImage` permission
- [ ] Check image tag format is correct
- [ ] Test login: `aws ecr get-login-password | docker login ...`

### EKS Pods Can't Pull Image

**Problem:** Pods show `ImagePullBackOff`

**Solutions:**
- [ ] Check EKS node role has `AmazonEC2ContainerRegistryReadOnly`
- [ ] Verify image URI is correct in deployment
- [ ] Check ECR repository is in same region as EKS
- [ ] Describe pod: `kubectl describe pod <pod-name> -n production`

### Pipeline Fails at ECR Scan

**Problem:** ECR image scan stage fails

**Solutions:**
- [ ] Check image scanning is enabled on repository
- [ ] Verify IAM policy has `ecr:StartImageScan` permission
- [ ] Increase sleep time in Jenkinsfile (scan takes time)
- [ ] Make scan non-blocking (remove `exit 1` on failures)

---

## Success Criteria

✅ **ECR Repository**
- Repository created and configured
- Image scanning enabled
- Lifecycle policy applied

✅ **IAM Permissions**
- Jenkins role has ECR push permissions
- EKS node role has ECR pull permissions
- Policies attached correctly

✅ **Jenkins Pipeline**
- All stages pass successfully
- Images pushed to ECR
- ECR scan completes
- Deployment to EKS succeeds

✅ **Kubernetes Deployment**
- Pods running with ECR images
- No imagePullSecrets needed
- Application accessible

✅ **Application**
- Health check passes
- S3 integration works
- No errors in logs

---

## Next Steps After Success

1. **Set up monitoring**
   - CloudWatch for ECR metrics
   - Container Insights for EKS
   - Application logs

2. **Configure alerts**
   - ECR push failures
   - Image scan findings
   - Deployment failures

3. **Implement GitOps**
   - ArgoCD or Flux
   - Automated deployments
   - Rollback capabilities

4. **Add more environments**
   - Development
   - Staging
   - Production

5. **Enhance security**
   - Image signing
   - Policy enforcement
   - Vulnerability management

---

## Documentation Reference

- **Detailed Setup:** `ECR-JENKINS-SETUP.md`
- **Quick Reference:** `ECR-QUICK-START.md`
- **Migration Summary:** `ECR-MIGRATION-SUMMARY.md`
- **This Checklist:** `ECR-SETUP-CHECKLIST.md`

---

**Congratulations! Your CI/CD pipeline is now using AWS ECR!** 🎉
