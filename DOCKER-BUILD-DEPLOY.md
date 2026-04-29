# Docker Build and Deploy Guide

## Step-by-Step Instructions

### Step 1: Get Your Docker Hub Username

```powershell
# If you don't have a Docker Hub account, create one at https://hub.docker.com

# Login to Docker Hub
docker login
# Enter your username and password
```

### Step 2: Update deployment.yaml

Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username:

```yaml
image: YOUR_DOCKERHUB_USERNAME/springboot-app:1.0.0
```

**Examples:**
- If username is `john`: `john/springboot-app:1.0.0`
- If username is `mycompany`: `mycompany/springboot-app:1.0.0`

### Step 3: Build Your Application

```powershell
# Navigate to project root
cd C:\Users\bhava\OneDrive\Desktop\KIRO\EKS-Deploy-App-CICD-GitHub-Maven-Jenkins-Trivy-Docker-Nexus-AWS-S3-SonarQube

# Build with Maven
mvn clean package -DskipTests

# Verify JAR file was created
ls target/*.jar
```

### Step 4: Build Docker Image

```powershell
# Set your Docker Hub username
$DOCKER_USERNAME = "YOUR_DOCKERHUB_USERNAME"

# Build Docker image
docker build -t ${DOCKER_USERNAME}/springboot-app:1.0.0 .

# Verify image was created
docker images | Select-String "springboot-app"
```

### Step 5: Test Docker Image Locally (Optional)

```powershell
# Run container locally
docker run -d -p 8080:8080 --name springboot-test ${DOCKER_USERNAME}/springboot-app:1.0.0

# Test the application
curl http://localhost:8080

# Check logs
docker logs springboot-test

# Stop and remove test container
docker stop springboot-test
docker rm springboot-test
```

### Step 6: Push to Docker Hub

```powershell
# Login to Docker Hub (if not already logged in)
docker login

# Push image
docker push ${DOCKER_USERNAME}/springboot-app:1.0.0

# Verify on Docker Hub
# Go to https://hub.docker.com/r/${DOCKER_USERNAME}/springboot-app
```

### Step 7: Update deployment.yaml

```powershell
# Open deployment.yaml
notepad k8s\deployment.yaml

# Replace this line:
# image: YOUR_DOCKERHUB_USERNAME/springboot-app:1.0.0

# With your actual username, for example:
# image: john/springboot-app:1.0.0
```

Or use PowerShell to update it:

```powershell
$DOCKER_USERNAME = "YOUR_DOCKERHUB_USERNAME"

# Update deployment.yaml
(Get-Content k8s\deployment.yaml) -replace 'YOUR_DOCKERHUB_USERNAME', $DOCKER_USERNAME | Set-Content k8s\deployment.yaml

# Verify
Get-Content k8s\deployment.yaml | Select-String "image:"
```

### Step 8: Create Docker Registry Secret (If Using Private Repository)

```powershell
# If your Docker Hub repository is private, create a secret
kubectl create secret docker-registry docker-registry-secret `
  --docker-server=https://index.docker.io/v1/ `
  --docker-username=$DOCKER_USERNAME `
  --docker-password=YOUR_DOCKER_PASSWORD `
  --docker-email=YOUR_EMAIL `
  -n production

# If using public repository, you can skip this or delete the imagePullSecrets section
```

### Step 9: Deploy to EKS

```powershell
# Apply all Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check deployment status
kubectl get deployments -n production
kubectl get pods -n production

# Watch pods starting
kubectl get pods -n production -w
```

### Step 10: Verify Deployment

```powershell
# Check pod status
kubectl get pods -n production

# Check logs
kubectl logs -n production -l app=springboot-app

# Describe pod for details
kubectl describe pod -n production -l app=springboot-app

# Port forward to test
kubectl port-forward -n production svc/springboot-service 8080:8080

# Test in another terminal
curl http://localhost:8080
curl http://localhost:8080/api/s3/health
```

---

## Alternative: Use AWS ECR Instead of Docker Hub

If you prefer to use AWS ECR (Elastic Container Registry):

### Step 1: Create ECR Repository

```powershell
# Set variables
$REGION = "us-east-1"
$REPO_NAME = "springboot-app"

# Create ECR repository
aws ecr create-repository --repository-name $REPO_NAME --region $REGION

# Get repository URI
$ECR_URI = aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION --query "repositories[0].repositoryUri" --output text

Write-Host "ECR Repository URI: $ECR_URI"
```

### Step 2: Login to ECR

```powershell
# Get login password and login
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
```

### Step 3: Build and Push to ECR

```powershell
# Build image
docker build -t springboot-app:1.0.0 .

# Tag for ECR
docker tag springboot-app:1.0.0 ${ECR_URI}:1.0.0

# Push to ECR
docker push ${ECR_URI}:1.0.0
```

### Step 4: Update deployment.yaml for ECR

```yaml
containers:
- name: springboot-app
  image: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/springboot-app:1.0.0
  imagePullPolicy: Always
```

### Step 5: Create ECR Pull Secret (If Needed)

```powershell
# EKS nodes usually have ECR access by default
# If not, create a secret:

$ECR_TOKEN = aws ecr get-login-password --region $REGION
$ECR_SERVER = "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

kubectl create secret docker-registry ecr-registry-secret `
  --docker-server=$ECR_SERVER `
  --docker-username=AWS `
  --docker-password=$ECR_TOKEN `
  -n production
```

---

## Complete Deployment Script

Here's a complete script to build and deploy:

```powershell
# ===== Configuration =====
$DOCKER_USERNAME = "YOUR_DOCKERHUB_USERNAME"  # Change this!
$IMAGE_TAG = "1.0.0"
$NAMESPACE = "production"

Write-Host "=== Building and Deploying Spring Boot App ===" -ForegroundColor Cyan

# ===== Step 1: Build Application =====
Write-Host "`nStep 1: Building application with Maven..." -ForegroundColor Green
mvn clean package -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Host "Maven build failed!" -ForegroundColor Red
    exit 1
}

# ===== Step 2: Build Docker Image =====
Write-Host "`nStep 2: Building Docker image..." -ForegroundColor Green
docker build -t ${DOCKER_USERNAME}/springboot-app:${IMAGE_TAG} .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}

# ===== Step 3: Push to Docker Hub =====
Write-Host "`nStep 3: Pushing to Docker Hub..." -ForegroundColor Green
docker push ${DOCKER_USERNAME}/springboot-app:${IMAGE_TAG}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker push failed! Make sure you're logged in: docker login" -ForegroundColor Red
    exit 1
}

# ===== Step 4: Update deployment.yaml =====
Write-Host "`nStep 4: Updating deployment.yaml..." -ForegroundColor Green
(Get-Content k8s\deployment.yaml) -replace 'YOUR_DOCKERHUB_USERNAME', $DOCKER_USERNAME | Set-Content k8s\deployment.yaml

# ===== Step 5: Deploy to Kubernetes =====
Write-Host "`nStep 5: Deploying to Kubernetes..." -ForegroundColor Green

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# ===== Step 6: Wait for Deployment =====
Write-Host "`nStep 6: Waiting for deployment to be ready..." -ForegroundColor Green
kubectl rollout status deployment/springboot-app -n $NAMESPACE --timeout=300s

# ===== Step 7: Verify =====
Write-Host "`n=== Deployment Complete! ===" -ForegroundColor Cyan
Write-Host "`nPod Status:" -ForegroundColor Yellow
kubectl get pods -n $NAMESPACE -l app=springboot-app

Write-Host "`nService Status:" -ForegroundColor Yellow
kubectl get svc -n $NAMESPACE springboot-service

Write-Host "`nTo test the application:" -ForegroundColor Yellow
Write-Host "kubectl port-forward -n $NAMESPACE svc/springboot-service 8080:8080"
Write-Host "curl http://localhost:8080"
```

---

## Troubleshooting

### Issue: ImagePullBackOff

**Cause:** Kubernetes can't pull the Docker image

**Solutions:**
1. Check image name is correct
2. Make sure image exists on Docker Hub
3. If private repo, create imagePullSecret
4. Check Docker Hub repository is public

```powershell
# Check pod events
kubectl describe pod -n production -l app=springboot-app

# Check if image exists
docker pull ${DOCKER_USERNAME}/springboot-app:1.0.0
```

### Issue: CrashLoopBackOff

**Cause:** Application is crashing after starting

**Solutions:**
1. Check application logs
2. Verify environment variables
3. Check resource limits

```powershell
# Check logs
kubectl logs -n production -l app=springboot-app --tail=100

# Check previous logs if pod restarted
kubectl logs -n production -l app=springboot-app --previous
```

### Issue: Pods Not Starting

**Cause:** Resource constraints or configuration issues

**Solutions:**
```powershell
# Check pod status
kubectl get pods -n production

# Describe pod for details
kubectl describe pod -n production -l app=springboot-app

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'
```

---

## Image Naming Convention

### Docker Hub Format
```
username/repository:tag
```

**Examples:**
- `john/springboot-app:1.0.0`
- `mycompany/springboot-app:latest`
- `devteam/springboot-app:v2.1.0`

### AWS ECR Format
```
account-id.dkr.ecr.region.amazonaws.com/repository:tag
```

**Examples:**
- `123456789012.dkr.ecr.us-east-1.amazonaws.com/springboot-app:1.0.0`
- `123456789012.dkr.ecr.us-east-1.amazonaws.com/springboot-app:latest`

---

## Version Tagging Best Practices

```powershell
# Semantic versioning
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:1.0.0
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:1.0
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:1
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:latest

# Git commit SHA
$GIT_SHA = git rev-parse --short HEAD
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:${GIT_SHA}

# Build number (from Jenkins)
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:build-${BUILD_NUMBER}

# Date-based
$DATE = Get-Date -Format "yyyyMMdd"
docker tag app:latest ${DOCKER_USERNAME}/springboot-app:${DATE}
```

---

## Summary

1. ✅ Replace `YOUR_DOCKERHUB_USERNAME` with your actual username
2. ✅ Build application with Maven
3. ✅ Build Docker image
4. ✅ Push to Docker Hub or ECR
5. ✅ Update deployment.yaml
6. ✅ Deploy to EKS
7. ✅ Verify deployment

**Your image should look like:** `yourusername/springboot-app:1.0.0`
