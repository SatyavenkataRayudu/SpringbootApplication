# Pipeline Deployment Guide

## 1. Prepare Your Application

### Clone Repository

```bash
git clone https://github.com/your-username/springboot-eks-cicd.git
cd springboot-eks-cicd
```

### Update Configuration Files

#### Update Jenkinsfile

Edit environment variables in `Jenkinsfile`:

```groovy
environment {
    DOCKER_REGISTRY = 'your-dockerhub-username'  // or ECR URL
    AWS_REGION = 'us-east-1'
    EKS_CLUSTER_NAME = 'my-eks-cluster'
    S3_BUCKET = 'your-artifacts-bucket'
    K8S_NAMESPACE = 'production'
}
```

#### Update Kubernetes Manifests

Edit `k8s/serviceaccount.yaml`:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/springboot-app-role
```

Edit `k8s/ingress.yaml`:
```yaml
- host: your-domain.com  # Update with your domain
```

### Commit and Push

```bash
git add .
git commit -m "Configure pipeline for deployment"
git push origin main
```

## 2. Configure Jenkins Pipeline

### Create Pipeline Job

1. Jenkins Dashboard → New Item
2. Name: `springboot-eks-pipeline`
3. Type: Pipeline
4. Click OK

### Configure Pipeline

#### General Settings
- Description: "CI/CD pipeline for Spring Boot app to EKS"
- Discard old builds: Keep last 10 builds

#### Build Triggers
- ✓ GitHub hook trigger for GITScm polling

#### Pipeline Configuration
- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: `https://github.com/your-username/springboot-eks-cicd.git`
- Credentials: Select your GitHub credentials
- Branch: `*/main`
- Script Path: `Jenkinsfile`

### Save Configuration

## 3. Test Local Build

Before running the pipeline, test locally:

```bash
# Build application
mvn clean package

# Build Docker image
docker build -t springboot-app:test .

# Run container locally
docker run -d -p 8080:8080 springboot-app:test

# Test application
curl http://localhost:8080
curl http://localhost:8080/actuator/health

# Stop container
docker stop $(docker ps -q --filter ancestor=springboot-app:test)
```

## 4. Run First Pipeline Build

### Trigger Build

1. Go to Jenkins job
2. Click "Build Now"
3. Monitor build progress in Blue Ocean or Console Output

### Pipeline Stages

The pipeline will execute these stages:

1. **Checkout** - Clone repository
2. **Build** - Compile Java code
3. **Unit Tests** - Run tests with JaCoCo coverage
4. **SonarQube Analysis** - Code quality scan
5. **Quality Gate** - Wait for SonarQube results
6. **Package** - Create JAR file
7. **Publish to Nexus** - Upload artifact
8. **Build Docker Image** - Create container image
9. **Trivy Security Scan** - Scan for vulnerabilities
10. **Push Docker Image** - Push to registry
11. **Backup to S3** - Store artifacts in S3
12. **Update K8s Manifests** - Update deployment files
13. **Deploy to EKS** - Deploy to Kubernetes
14. **Health Check** - Verify deployment

### Monitor Build

```bash
# Watch Jenkins logs
# Or use Blue Ocean UI for better visualization

# Monitor Kubernetes deployment
kubectl get pods -n production -w

# Check deployment status
kubectl rollout status deployment/springboot-app -n production
```

## 5. Verify Deployment

### Check Kubernetes Resources

```bash
# Check namespace
kubectl get all -n production

# Check pods
kubectl get pods -n production
kubectl describe pod <pod-name> -n production

# Check service
kubectl get svc -n production

# Check ingress
kubectl get ingress -n production

# Get application logs
kubectl logs -f deployment/springboot-app -n production
```

### Test Application

```bash
# Get Load Balancer URL
kubectl get ingress -n production

# Test endpoints
curl http://your-alb-url/
curl http://your-alb-url/actuator/health
curl http://your-alb-url/api/info

# Or use port-forward for testing
kubectl port-forward svc/springboot-app-service 8080:80 -n production
curl http://localhost:8080
```

## 6. Configure Automatic Deployments

### GitHub Webhook

1. GitHub Repository → Settings → Webhooks
2. Add webhook:
   - Payload URL: `http://your-jenkins-ip:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event
   - Active: ✓

### Test Webhook

```bash
# Make a change
echo "# Test change" >> README.md
git add README.md
git commit -m "Test webhook trigger"
git push origin main

# Check Jenkins - build should start automatically
```

## 7. Monitoring and Logging

### View Application Logs

```bash
# Real-time logs
kubectl logs -f deployment/springboot-app -n production

# Logs from all pods
kubectl logs -l app=springboot-app -n production --tail=100

# Previous container logs (if pod crashed)
kubectl logs <pod-name> -n production --previous
```

### CloudWatch Logs

```bash
# View logs in AWS Console
# CloudWatch → Log groups → /aws/eks/my-eks-cluster/cluster

# Or use AWS CLI
aws logs tail /aws/eks/my-eks-cluster/cluster --follow
```

### Prometheus Metrics

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Grafana at http://localhost:3000
# Username: admin
# Password: (from earlier setup)
```

## 8. Rollback Procedures

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/springboot-app -n production

# Rollback to previous version
kubectl rollout undo deployment/springboot-app -n production

# Rollback to specific revision
kubectl rollout undo deployment/springboot-app -n production --to-revision=2

# Check rollback status
kubectl rollout status deployment/springboot-app -n production
```

### Rollback via Jenkins

1. Go to previous successful build
2. Click "Replay"
3. Or manually trigger build with specific version

## 9. Scaling

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment springboot-app --replicas=5 -n production

# Verify
kubectl get pods -n production
```

### Auto-scaling (HPA)

```bash
# Apply HPA
kubectl apply -f k8s/hpa.yaml

# Check HPA status
kubectl get hpa -n production

# Describe HPA
kubectl describe hpa springboot-app-hpa -n production
```

### Load Testing

```bash
# Install hey (HTTP load generator)
go install github.com/rakyll/hey@latest

# Run load test
hey -z 2m -c 50 http://your-alb-url/

# Watch HPA scale
kubectl get hpa -n production -w
```

## 10. Troubleshooting

### Common Issues

#### Pipeline Fails at SonarQube Stage

```bash
# Check SonarQube is running
docker ps | grep sonarqube

# Check SonarQube logs
docker logs sonarqube

# Verify token in Jenkins credentials
```

#### Docker Push Fails

```bash
# Verify Docker credentials
docker login

# Check Jenkins credentials
# Manage Jenkins → Credentials

# Test manual push
docker push your-registry/springboot-app:test
```

#### EKS Deployment Fails

```bash
# Check kubectl access from Jenkins
sudo su - jenkins
kubectl get nodes

# Update kubeconfig
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1

# Check RBAC permissions
kubectl auth can-i create deployments -n production --as=system:serviceaccount:production:jenkins-deployer
```

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n production

# Describe pod
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Common issues:
# - Image pull errors: Check registry credentials
# - Resource limits: Check node capacity
# - ConfigMap/Secret missing: Apply k8s manifests
```

#### Ingress Not Working

```bash
# Check ingress
kubectl get ingress -n production
kubectl describe ingress springboot-app-ingress -n production

# Check ALB controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ALB in AWS Console
aws elbv2 describe-load-balancers
```

## 11. Security Scan Results

### Review Trivy Reports

```bash
# Download from Jenkins artifacts
# Or from S3
aws s3 cp s3://your-bucket/security-reports/springboot-app/latest/trivy-report.json .

# View critical vulnerabilities
cat trivy-report.json | jq '.Results[].Vulnerabilities[] | select(.Severity=="CRITICAL")'
```

### Review SonarQube Results

1. Open SonarQube dashboard
2. Navigate to project
3. Review:
   - Bugs
   - Vulnerabilities
   - Code Smells
   - Coverage
   - Duplications

## 12. Backup and Recovery

### Backup Application

```bash
# Create backup using Velero
velero backup create springboot-app-backup --include-namespaces production

# Check backup status
velero backup describe springboot-app-backup

# List backups
velero backup get
```

### Restore Application

```bash
# Restore from backup
velero restore create --from-backup springboot-app-backup

# Check restore status
velero restore describe springboot-app-backup-<timestamp>
```

## 13. Production Checklist

Before going to production:

- [ ] Update all placeholder values (domain, AWS account, etc.)
- [ ] Configure HTTPS/TLS certificates
- [ ] Set up proper DNS records
- [ ] Configure resource limits appropriately
- [ ] Enable pod disruption budgets
- [ ] Set up monitoring alerts
- [ ] Configure log aggregation
- [ ] Enable backup schedules
- [ ] Document runbooks
- [ ] Test disaster recovery procedures
- [ ] Configure network policies
- [ ] Enable pod security policies
- [ ] Set up cost monitoring
- [ ] Configure auto-scaling policies

## Next Steps

- Set up monitoring dashboards
- Configure alerting (PagerDuty, Slack, etc.)
- Implement blue-green or canary deployments
- Add integration tests to pipeline
- Set up staging environment
- Configure database backups
- Implement secrets management (AWS Secrets Manager)
- Add performance testing
