# Jenkins CI/CD Quick Start Checklist

Follow these steps in order to set up your complete CI/CD pipeline.

---

## Step 1: Update Jenkinsfile (5 minutes)

Open `Jenkinsfile` and update these values:

```groovy
DOCKER_USERNAME = 'YOUR_DOCKERHUB_USERNAME'  // Line 8 - Change this!
EKS_CLUSTER_NAME = 'my-eks-cluster'          // Line 13 - Your cluster name
S3_BUCKET = 'my-artifacts-bucket-20260427170349'  // Line 14 - Your bucket
```

**Quick PowerShell Update:**
```powershell
$DOCKER_USER = "your-dockerhub-username"
(Get-Content Jenkinsfile) -replace 'YOUR_DOCKERHUB_USERNAME', $DOCKER_USER | Set-Content Jenkinsfile
```

---

## Step 2: Configure Jenkins Credentials (10 minutes)

Go to: **Manage Jenkins → Manage Credentials → Global → Add Credentials**

### Add These 5 Credentials:

| ID | Type | Values |
|----|------|--------|
| `docker-credentials` | Username/Password | Docker Hub username & password |
| `aws-credentials` | AWS Credentials | AWS Access Key & Secret Key |
| `sonarqube-token` | Secret Text | Token from SonarQube |
| `nexus-credentials` | Username/Password | Nexus admin credentials |
| `github-credentials` | Username/Password | GitHub username & Personal Access Token |

---

## Step 3: Configure Jenkins Tools (5 minutes)

### Maven
```
Manage Jenkins → Global Tool Configuration → Maven
Name: Maven-3.9
Install automatically: ✅
```

### JDK
```
Manage Jenkins → Global Tool Configuration → JDK
Name: JDK-17
Install automatically: ✅
```

### SonarQube Scanner
```
Manage Jenkins → Global Tool Configuration → SonarQube Scanner
Name: SonarQube Scanner
Install automatically: ✅
```

---

## Step 4: Configure SonarQube Server (2 minutes)

```
Manage Jenkins → Configure System → SonarQube servers
Name: SonarQube
Server URL: http://your-sonarqube-ip:9000
Token: Select 'sonarqube-token'
```

---

## Step 5: Create Pipeline Job (5 minutes)

1. **New Item** → Enter name: `springboot-eks-pipeline` → **Pipeline** → OK

2. **Configure:**
   - ✅ GitHub project: `https://github.com/your-username/your-repo`
   - ✅ GitHub hook trigger for GITScm polling
   
3. **Pipeline:**
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/your-username/your-repo.git`
   - Credentials: Select `github-credentials`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

4. **Save**

---

## Step 6: Configure GitHub Webhook (2 minutes)

1. Go to your GitHub repository
2. **Settings → Webhooks → Add webhook**
3. **Payload URL:** `http://your-jenkins-ip:8080/github-webhook/`
4. **Content type:** `application/json`
5. **Events:** Just the push event
6. ✅ Active
7. **Add webhook**

---

## Step 7: Push Code to GitHub (2 minutes)

```powershell
# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit with CI/CD pipeline"

# Add remote
git remote add origin https://github.com/your-username/your-repo.git

# Push
git push -u origin main
```

---

## Step 8: Run First Build (1 minute)

1. Go to Jenkins → `springboot-eks-pipeline`
2. Click **Build Now**
3. Watch the pipeline execute
4. Check each stage for success ✅

---

## Step 9: Verify Deployment (2 minutes)

```powershell
# Check pods
kubectl get pods -n production

# Check deployment
kubectl get deployment springboot-app -n production

# Port forward
kubectl port-forward -n production svc/springboot-service 8080:8080

# Test (in another terminal)
curl http://localhost:8080
curl http://localhost:8080/api/s3/health
```

---

## Step 10: Test Automatic Deployment (2 minutes)

1. Make a small code change
2. Commit and push:
```powershell
git add .
git commit -m "Test automatic deployment"
git push
```
3. Watch Jenkins automatically trigger
4. Verify new deployment in EKS

---

## Troubleshooting Quick Fixes

### Jenkins Can't Access Docker
```bash
# On Jenkins server
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Jenkins Can't Access kubectl
```bash
# On Jenkins server
sudo su - jenkins
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
kubectl get nodes
```

### Docker Login Failed
```bash
# On Jenkins server
sudo su - jenkins
docker login
# Enter credentials
```

### AWS Credentials Not Working
```bash
# On Jenkins server
sudo su - jenkins
aws configure
# Enter AWS credentials
```

---

## Expected Pipeline Duration

| Stage | Time |
|-------|------|
| Checkout | 10s |
| Build | 30s |
| Unit Tests | 20s |
| SonarQube Analysis | 1m |
| Quality Gate | 30s |
| Package | 20s |
| Publish to Nexus | 15s |
| Build Docker Image | 1m |
| Trivy Scan | 30s |
| Push Docker Image | 1m |
| Backup to S3 | 10s |
| Deploy to EKS | 1m |
| Health Check | 30s |
| **Total** | **~7-8 minutes** |

---

## Success Indicators

✅ All stages green in Jenkins
✅ Pods running in EKS: `kubectl get pods -n production`
✅ Application accessible: `curl http://localhost:8080`
✅ S3 has artifacts: Check S3 bucket
✅ Nexus has artifacts: Check Nexus UI
✅ SonarQube shows analysis: Check SonarQube dashboard

---

## What Happens on Each Git Push

1. **GitHub** receives your push
2. **Webhook** notifies Jenkins
3. **Jenkins** starts pipeline automatically
4. **Maven** builds and tests code
5. **SonarQube** analyzes code quality
6. **Docker** builds new image
7. **Trivy** scans for vulnerabilities
8. **Docker Hub** receives new image
9. **S3** stores artifacts
10. **EKS** deploys new version
11. **Kubernetes** performs rolling update
12. **Application** is live with zero downtime!

---

## Total Setup Time

- ⏱️ **First time:** 30-40 minutes
- ⏱️ **Subsequent builds:** 7-8 minutes (automatic)

---

## Next Steps After Setup

1. ✅ Add Slack/Email notifications
2. ✅ Set up staging environment
3. ✅ Add integration tests
4. ✅ Configure blue-green deployment
5. ✅ Add monitoring (Prometheus/Grafana)
6. ✅ Set up log aggregation (ELK stack)

---

## Quick Reference Commands

```powershell
# Check Jenkins logs
sudo journalctl -u jenkins -f

# Restart Jenkins
sudo systemctl restart jenkins

# Check pipeline in Jenkins
# http://your-jenkins-ip:8080/job/springboot-eks-pipeline/

# Check pods in EKS
kubectl get pods -n production -w

# View application logs
kubectl logs -n production -l app=springboot-app -f

# Rollback deployment
kubectl rollout undo deployment/springboot-app -n production

# Check deployment history
kubectl rollout history deployment/springboot-app -n production
```

---

## You're Done! 🎉

Your complete CI/CD pipeline is now set up. Every time you push code to GitHub, it will automatically:
- Build
- Test
- Analyze
- Scan
- Deploy to EKS

**No manual steps required!**
