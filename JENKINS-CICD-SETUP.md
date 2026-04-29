# Jenkins CI/CD Pipeline Setup Guide

Complete guide to set up Jenkins for automated deployment to AWS EKS.

---

## Prerequisites

Before starting, ensure you have:
- ✅ Jenkins server running (see `docs/02-jenkins-setup.md`)
- ✅ SonarQube server running (see `docs/03-sonarqube-setup.md`)
- ✅ Nexus server running (see `docs/04-nexus-setup.md`)
- ✅ EKS cluster created
- ✅ Docker Hub account or AWS ECR
- ✅ GitHub repository with your code

---

## Part 1: Configure Jenkins Credentials

### 1. Docker Hub Credentials

```
Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Type:** Username with password
- **ID:** `docker-credentials`
- **Username:** Your Docker Hub username
- **Password:** Your Docker Hub password
- **Description:** Docker Hub credentials

### 2. Docker Registry URL

**Type:** Secret text
- **ID:** `docker-registry-url`
- **Secret:** `your-dockerhub-username` (just the username, not full URL)
- **Description:** Docker registry URL

**Example:** If username is `john`, enter: `john`

### 3. AWS Credentials

**Type:** AWS Credentials
- **ID:** `aws-credentials`
- **Access Key ID:** Your AWS access key
- **Secret Access Key:** Your AWS secret key
- **Description:** AWS credentials for EKS and S3

### 4. SonarQube Token

**Type:** Secret text
- **ID:** `sonarqube-token`
- **Secret:** Your SonarQube token (from SonarQube → My Account → Security)
- **Description:** SonarQube authentication token

### 5. Nexus Credentials

**Type:** Username with password
- **ID:** `nexus-credentials`
- **Username:** `admin` (or your Nexus username)
- **Password:** Your Nexus password
- **Description:** Nexus repository credentials

### 6. GitHub Credentials (for webhook)

**Type:** Username with password or Personal Access Token
- **ID:** `github-credentials`
- **Username:** Your GitHub username
- **Password:** GitHub Personal Access Token
- **Description:** GitHub credentials

---

## Part 2: Configure Jenkins Global Tools

### 1. Configure Maven

```
Manage Jenkins → Global Tool Configuration → Maven
```

- **Name:** `Maven-3.9`
- **Install automatically:** ✅ Yes
- **Version:** 3.9.x (latest)

### 2. Configure JDK

```
Manage Jenkins → Global Tool Configuration → JDK
```

- **Name:** `JDK-17`
- **Install automatically:** ✅ Yes
- **Version:** Java 17

Or use existing installation:
- **JAVA_HOME:** `/usr/lib/jvm/java-17-openjdk-amd64`

### 3. Configure SonarQube Scanner

```
Manage Jenkins → Global Tool Configuration → SonarQube Scanner
```

- **Name:** `SonarQube Scanner`
- **Install automatically:** ✅ Yes
- **Version:** Latest

---

## Part 3: Configure SonarQube Server

```
Manage Jenkins → Configure System → SonarQube servers
```

- **Name:** `SonarQube`
- **Server URL:** `http://your-sonarqube-ip:9000`
- **Server authentication token:** Select `sonarqube-token` credential

---

## Part 4: Update Jenkinsfile for Your Environment

Update these values in your `Jenkinsfile`:

```groovy
environment {
    // Docker - Update with your Docker Hub username
    DOCKER_REGISTRY = credentials('docker-registry-url')  // Your Docker Hub username
    
    // AWS - Update with your values
    AWS_REGION = 'us-east-1'
    EKS_CLUSTER_NAME = 'my-eks-cluster'  // Your EKS cluster name
    S3_BUCKET = 'my-artifacts-bucket-20260427170349'  // Your S3 bucket
    
    // Kubernetes
    K8S_NAMESPACE = 'production'
}
```

### Quick Update Script

```powershell
# Set your values
$DOCKER_USERNAME = "your-dockerhub-username"
$EKS_CLUSTER = "my-eks-cluster"
$S3_BUCKET = "my-artifacts-bucket-20260427170349"

# Update Jenkinsfile
$jenkinsfile = Get-Content Jenkinsfile -Raw
$jenkinsfile = $jenkinsfile -replace "DOCKER_REGISTRY = credentials\('docker-registry-url'\)", "DOCKER_REGISTRY = '$DOCKER_USERNAME'"
$jenkinsfile = $jenkinsfile -replace "EKS_CLUSTER_NAME = 'my-eks-cluster'", "EKS_CLUSTER_NAME = '$EKS_CLUSTER'"
$jenkinsfile = $jenkinsfile -replace "S3_BUCKET = 'my-artifacts-bucket'", "S3_BUCKET = '$S3_BUCKET'"
$jenkinsfile | Set-Content Jenkinsfile
```

---

## Part 5: Create Jenkins Pipeline Job

### Step 1: Create New Pipeline

1. Jenkins Dashboard → New Item
2. Enter name: `springboot-eks-pipeline`
3. Select: **Pipeline**
4. Click OK

### Step 2: Configure Pipeline

**General:**
- ✅ GitHub project
- Project URL: `https://github.com/your-username/your-repo`

**Build Triggers:**
- ✅ GitHub hook trigger for GITScm polling

**Pipeline:**
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/your-username/your-repo.git`
- **Credentials:** Select `github-credentials`
- **Branch:** `*/main` (or your branch name)
- **Script Path:** `Jenkinsfile`

### Step 3: Save

---

## Part 6: Configure GitHub Webhook

### Step 1: Get Jenkins URL

Your Jenkins webhook URL:
```
http://your-jenkins-ip:8080/github-webhook/
```

### Step 2: Add Webhook in GitHub

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. **Payload URL:** `http://your-jenkins-ip:8080/github-webhook/`
4. **Content type:** `application/json`
5. **Which events:** Just the push event
6. ✅ Active
7. Add webhook

---

## Part 7: Update Deployment YAML

Update `k8s/deployment.yaml` to use environment variables from Jenkins:

```yaml
containers:
- name: springboot-app
  image: ${DOCKER_REGISTRY}/springboot-app:${IMAGE_TAG}
  imagePullPolicy: Always
```

The Jenkinsfile will replace these placeholders during deployment.

---

## Part 8: Test the Pipeline

### Manual Trigger (First Time)

1. Go to Jenkins → Your Pipeline
2. Click "Build Now"
3. Watch the pipeline execute

### Stages You'll See:

1. ✅ **Checkout** - Clone repository
2. ✅ **Build** - Maven compile
3. ✅ **Unit Tests** - Run tests
4. ✅ **SonarQube Analysis** - Code quality check
5. ✅ **Quality Gate** - Wait for SonarQube result
6. ✅ **Package** - Create JAR file
7. ✅ **Publish to Nexus** - Upload artifact
8. ✅ **Build Docker Image** - Create container image
9. ✅ **Trivy Security Scan** - Scan for vulnerabilities
10. ✅ **Push Docker Image** - Push to Docker Hub
11. ✅ **Backup to S3** - Backup artifacts
12. ✅ **Update K8s Manifests** - Update deployment files
13. ✅ **Deploy to EKS** - Deploy to Kubernetes
14. ✅ **Health Check** - Verify deployment

### Automatic Trigger (After Setup)

1. Make a code change
2. Commit and push to GitHub
3. GitHub webhook triggers Jenkins
4. Pipeline runs automatically
5. Application deploys to EKS

---

## Part 9: Monitor Pipeline

### View Pipeline Progress

```
Jenkins → Your Pipeline → Build History → #BuildNumber
```

### View Console Output

Click on build number → Console Output

### View Stage View

Blue Ocean view (if installed):
```
Jenkins → Open Blue Ocean → Your Pipeline
```

---

## Part 10: Verify Deployment in EKS

After pipeline completes:

```powershell
# Check pods
kubectl get pods -n production

# Check deployment
kubectl get deployment springboot-app -n production

# Check service
kubectl get svc springboot-service -n production

# View logs
kubectl logs -n production -l app=springboot-app

# Port forward to test
kubectl port-forward -n production svc/springboot-service 8080:8080

# Test application
curl http://localhost:8080
curl http://localhost:8080/api/s3/health
```

---

## Troubleshooting

### Issue 1: Docker Login Failed

**Error:** `unauthorized: authentication required`

**Solution:**
```powershell
# On Jenkins server
docker login
# Enter credentials

# Or check Jenkins credentials
# Manage Jenkins → Manage Credentials → docker-credentials
```

### Issue 2: AWS Credentials Not Working

**Error:** `Unable to locate credentials`

**Solution:**
```powershell
# On Jenkins server, configure AWS CLI
sudo su - jenkins
aws configure
# Enter AWS credentials

# Or use IAM role (recommended)
# Attach IAM role to Jenkins EC2 instance
```

### Issue 3: kubectl Not Found

**Error:** `kubectl: command not found`

**Solution:**
```bash
# On Jenkins server
sudo su - jenkins
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### Issue 4: EKS Cluster Not Accessible

**Error:** `error: You must be logged in to the server`

**Solution:**
```bash
# On Jenkins server
sudo su - jenkins
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
kubectl get nodes
```

### Issue 5: SonarQube Quality Gate Failed

**Error:** `Quality gate failed`

**Solution:**
- Check SonarQube dashboard for issues
- Fix code quality issues
- Or adjust quality gate settings in SonarQube

### Issue 6: Trivy Scan Failed

**Error:** `Vulnerabilities found`

**Solution:**
- Review trivy-report.json
- Update base image or dependencies
- Or adjust severity threshold in Jenkinsfile

---

## Pipeline Optimization

### 1. Parallel Stages

```groovy
stage('Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'mvn verify'
            }
        }
    }
}
```

### 2. Skip Stages Based on Branch

```groovy
stage('Deploy to Production') {
    when {
        branch 'main'
    }
    steps {
        // Deploy only from main branch
    }
}
```

### 3. Add Notifications

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "Pipeline succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "Pipeline failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

---

## Complete Setup Checklist

### Jenkins Configuration
- [ ] Jenkins installed and running
- [ ] All plugins installed (Git, Maven, Docker, Kubernetes, SonarQube, AWS)
- [ ] Maven configured
- [ ] JDK configured
- [ ] SonarQube scanner configured

### Credentials
- [ ] Docker Hub credentials added
- [ ] Docker registry URL added
- [ ] AWS credentials added
- [ ] SonarQube token added
- [ ] Nexus credentials added
- [ ] GitHub credentials added

### External Services
- [ ] SonarQube server configured in Jenkins
- [ ] Nexus server accessible
- [ ] EKS cluster created
- [ ] S3 bucket created
- [ ] IAM roles configured

### Pipeline
- [ ] Jenkinsfile updated with correct values
- [ ] Pipeline job created
- [ ] GitHub webhook configured
- [ ] First build successful

### Verification
- [ ] Application deployed to EKS
- [ ] Pods running
- [ ] Service accessible
- [ ] Health checks passing

---

## Next Steps

1. ✅ Complete Jenkins setup
2. ✅ Configure all credentials
3. ✅ Update Jenkinsfile with your values
4. ✅ Create pipeline job
5. ✅ Configure GitHub webhook
6. ✅ Run first build
7. ✅ Verify deployment
8. ✅ Make a code change and push
9. ✅ Watch automatic deployment

---

## Summary

Your CI/CD pipeline will:
1. **Build** - Compile code with Maven
2. **Test** - Run unit tests
3. **Analyze** - Check code quality with SonarQube
4. **Package** - Create JAR file
5. **Publish** - Upload to Nexus
6. **Containerize** - Build Docker image
7. **Scan** - Security scan with Trivy
8. **Push** - Upload to Docker Hub
9. **Backup** - Store in S3
10. **Deploy** - Deploy to EKS
11. **Verify** - Health checks

**All automatically triggered by a git push!** 🚀
