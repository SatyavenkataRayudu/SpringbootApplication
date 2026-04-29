# Complete Installation and Configuration Steps

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Installation](#detailed-installation)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Best Practices](#best-practices)

---

## Prerequisites

### Required Accounts
- ✅ AWS Account with admin access
- ✅ GitHub account
- ✅ Docker Hub account (or use AWS ECR)

### Required Tools Installation

```bash
# 1. AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# 2. kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# 3. eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# 4. Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# 5. Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
docker --version

# 6. Maven
sudo apt update
sudo apt install -y maven
mvn -version

# 7. Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
trivy --version
```

---

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/your-username/springboot-eks-cicd.git
cd springboot-eks-cicd

# 2. Configure AWS
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1), Output (json)

# 3. Run automated setup
chmod +x scripts/setup-all.sh
./scripts/setup-all.sh

# Follow prompts to enter:
# - AWS Region
# - EKS Cluster Name
# - S3 Bucket Name
# - Docker Registry
# - GitHub Repository URL
```

### Option 2: Manual Setup

Follow the detailed steps below.

---

## Detailed Installation

### Phase 1: AWS Infrastructure (30 minutes)

#### 1.1 Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

#### 1.2 Create S3 Bucket

```bash
# Create bucket with unique name
BUCKET_NAME="my-cicd-artifacts-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Save bucket name for later
echo $BUCKET_NAME > bucket-name.txt
```

#### 1.3 Create IAM Policy for Jenkins

```bash
cat > jenkins-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage"
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

### Phase 2: Jenkins Server Setup (45 minutes)

#### 2.1 Launch EC2 Instance

```bash
# Launch Ubuntu 22.04 instance (t3.medium or larger)
# Security Group: Allow ports 22, 8080, 50000

# Get instance ID after launch
INSTANCE_ID="i-xxxxxxxxxxxxx"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
JENKINS_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Jenkins IP: $JENKINS_IP"
```

#### 2.2 Install Jenkins

```bash
# SSH to instance
ssh -i your-key.pem ubuntu@$JENKINS_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Install Java
sudo apt install -y openjdk-17-jdk

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### 2.3 Install Additional Tools on Jenkins Server

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Install Maven
sudo apt install -y maven

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Verify installations
docker --version
mvn -version
aws --version
kubectl version --client
trivy --version
```

#### 2.4 Configure Jenkins

```bash
# Access Jenkins at http://$JENKINS_IP:8080
# 1. Enter initial admin password
# 2. Install suggested plugins
# 3. Create admin user
# 4. Save and finish
```

#### 2.5 Install Jenkins Plugins

Navigate to: Manage Jenkins → Manage Plugins → Available

Install these plugins:
- ✅ Pipeline
- ✅ Git
- ✅ Maven Integration
- ✅ Docker Pipeline
- ✅ Kubernetes
- ✅ AWS Steps
- ✅ SonarQube Scanner
- ✅ Nexus Artifact Uploader
- ✅ Blue Ocean (optional)

Restart Jenkins after installation.

### Phase 3: SonarQube Setup (20 minutes)

#### 3.1 Install SonarQube

```bash
# On a separate server or same Jenkins server

# Set system parameters
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf

# Create network
docker network create sonarnet

# Run PostgreSQL
docker run -d \
  --name sonarqube-db \
  --network sonarnet \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  -e POSTGRES_DB=sonarqube \
  -v postgresql_data:/var/lib/postgresql/data \
  postgres:15-alpine

# Run SonarQube
docker run -d \
  --name sonarqube \
  --network sonarnet \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:lts-community

# Wait for SonarQube to start (2-3 minutes)
docker logs -f sonarqube
```

#### 3.2 Configure SonarQube

```bash
# Access SonarQube at http://server-ip:9000
# Default credentials: admin/admin
# Change password when prompted

# Generate token:
# 1. Profile → My Account → Security
# 2. Generate Token
# 3. Name: jenkins-token
# 4. Copy token (save securely)
```

### Phase 4: Nexus Setup (20 minutes)

#### 4.1 Install Nexus

```bash
# Create volume
docker volume create nexus-data

# Run Nexus
docker run -d \
  --name nexus \
  -p 8081:8081 \
  -p 8082:8082 \
  -v nexus-data:/nexus-data \
  -e INSTALL4J_ADD_VM_PARAMS="-Xms2g -Xmx2g" \
  sonatype/nexus3:latest

# Wait for Nexus to start (2-3 minutes)
docker logs -f nexus

# Get initial password
docker exec nexus cat /nexus-data/admin.password
```

#### 4.2 Configure Nexus

```bash
# Access Nexus at http://server-ip:8081
# 1. Sign in with admin and password from above
# 2. Complete setup wizard
# 3. Change admin password
# 4. Enable anonymous access (optional)

# Create repositories:
# 1. Settings → Repositories → Create repository
# 2. Create maven2 (hosted) - maven-releases
# 3. Create maven2 (hosted) - maven-snapshots
# 4. Create docker (hosted) - docker-hosted (port 8082)
```

### Phase 5: EKS Cluster Setup (60 minutes)

#### 5.1 Create EKS Cluster

```bash
# Create cluster configuration
cat > eks-cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-eks-cluster
  region: us-east-1
  version: "1.28"

iam:
  withOIDC: true

managedNodeGroups:
  - name: ng-1
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    volumeSize: 30

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
EOF

# Create cluster (takes 15-20 minutes)
eksctl create cluster -f eks-cluster-config.yaml

# Verify
kubectl get nodes
```

#### 5.2 Install Add-ons

```bash
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-eks-cluster

# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get pods -n kube-system
```

#### 5.3 Create Namespace and Secrets

```bash
# Create namespace
kubectl create namespace production

# Create Docker registry secret
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --docker-email=YOUR_EMAIL \
  -n production
```

### Phase 6: Jenkins Configuration (30 minutes)

#### 6.1 Configure AWS on Jenkins

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@$JENKINS_IP

# Switch to jenkins user
sudo su - jenkins

# Configure AWS
aws configure
# Enter your AWS credentials

# Update kubeconfig
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1

# Test
kubectl get nodes
```

#### 6.2 Add Credentials in Jenkins

Navigate to: Manage Jenkins → Manage Credentials → Global → Add Credentials

Add these credentials:

1. **AWS Credentials**
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key

2. **Docker Credentials**
   - Kind: Username with password
   - ID: `docker-credentials`
   - Username: Docker Hub username
   - Password: Docker Hub password

3. **Docker Registry URL**
   - Kind: Secret text
   - ID: `docker-registry-url`
   - Secret: `docker.io/your-username`

4. **SonarQube Token**
   - Kind: Secret text
   - ID: `sonarqube-token`
   - Secret: Token from SonarQube

5. **Nexus Credentials**
   - Kind: Username with password
   - ID: `nexus-credentials`
   - Username: admin
   - Password: Nexus password

6. **GitHub Credentials**
   - Kind: Username with password
   - ID: `github-credentials`
   - Username: GitHub username
   - Password: Personal Access Token

#### 6.3 Configure SonarQube in Jenkins

1. Manage Jenkins → Configure System
2. SonarQube servers section:
   - Name: `SonarQube`
   - Server URL: `http://sonarqube-server-ip:9000`
   - Server authentication token: Select `sonarqube-token`

3. Manage Jenkins → Global Tool Configuration
4. SonarQube Scanner:
   - Name: `SonarQube Scanner`
   - Install automatically: Yes

#### 6.4 Create Pipeline Job

1. New Item → Pipeline
2. Name: `springboot-eks-pipeline`
3. Pipeline Definition: Pipeline script from SCM
4. SCM: Git
5. Repository URL: Your GitHub repo
6. Credentials: `github-credentials`
7. Branch: `*/main`
8. Script Path: `Jenkinsfile`
9. Save

### Phase 7: Application Deployment (15 minutes)

#### 7.1 Update Configuration

```bash
# Clone your repository
git clone https://github.com/your-username/springboot-eks-cicd.git
cd springboot-eks-cicd

# Update Jenkinsfile environment variables
nano Jenkinsfile
# Update:
# - DOCKER_REGISTRY
# - AWS_REGION
# - EKS_CLUSTER_NAME
# - S3_BUCKET

# Update k8s/serviceaccount.yaml
nano k8s/serviceaccount.yaml
# Update AWS account ID in role ARN

# Commit changes
git add .
git commit -m "Configure for deployment"
git push origin main
```

#### 7.2 Run Pipeline

1. Go to Jenkins → springboot-eks-pipeline
2. Click "Build Now"
3. Monitor progress in Blue Ocean or Console Output

#### 7.3 Verify Deployment

```bash
# Check pods
kubectl get pods -n production

# Check service
kubectl get svc -n production

# Check ingress
kubectl get ingress -n production

# Get application logs
kubectl logs -f deployment/springboot-app -n production

# Test application
kubectl port-forward svc/springboot-app-service 8080:80 -n production
curl http://localhost:8080
```

---

## Configuration

### Update Application Settings

Edit `src/main/resources/application.yml` for application-specific configuration.

### Update Kubernetes Resources

Modify files in `k8s/` directory:
- `deployment.yaml` - Replicas, resources, image
- `service.yaml` - Service type, ports
- `ingress.yaml` - Domain, TLS settings
- `hpa.yaml` - Auto-scaling thresholds

### Update Pipeline

Modify `Jenkinsfile` to:
- Add/remove stages
- Change build parameters
- Update deployment strategy

---

## Verification

### Check All Components

```bash
# Jenkins
curl http://$JENKINS_IP:8080

# SonarQube
curl http://sonarqube-ip:9000

# Nexus
curl http://nexus-ip:8081

# EKS Cluster
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Application
kubectl get all -n production
```

---

## Best Practices

### Security
1. ✅ Use HTTPS for all services
2. ✅ Rotate credentials regularly
3. ✅ Enable MFA on AWS account
4. ✅ Use AWS Secrets Manager for sensitive data
5. ✅ Implement network policies
6. ✅ Enable pod security standards
7. ✅ Regular security scans with Trivy
8. ✅ Keep all tools updated

### High Availability
1. ✅ Use multiple replicas (minimum 3)
2. ✅ Configure pod disruption budgets
3. ✅ Use rolling update strategy
4. ✅ Implement health checks
5. ✅ Multi-AZ deployment
6. ✅ Regular backups

### Monitoring
1. ✅ Set up CloudWatch alarms
2. ✅ Configure Prometheus/Grafana
3. ✅ Enable application metrics
4. ✅ Log aggregation
5. ✅ Regular health checks

### Cost Optimization
1. ✅ Use appropriate instance types
2. ✅ Enable cluster autoscaler
3. ✅ Set resource limits
4. ✅ Use Spot instances where possible
5. ✅ Regular cost reviews
6. ✅ Delete unused resources

---

## Next Steps

1. Set up monitoring dashboards
2. Configure alerting (Slack, PagerDuty)
3. Implement blue-green deployments
4. Add integration tests
5. Set up staging environment
6. Configure database (if needed)
7. Implement secrets management
8. Add performance testing

---

## Support

For issues or questions:
1. Check documentation in `docs/` directory
2. Review troubleshooting section in DEPLOYMENT_GUIDE.md
3. Check logs: `kubectl logs`, `docker logs`
4. Verify configurations

---

## Cleanup

To remove all resources:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

Or manually:
```bash
# Delete EKS cluster
eksctl delete cluster --name my-eks-cluster --region us-east-1

# Delete S3 bucket
aws s3 rb s3://your-bucket --force

# Stop Docker containers
docker stop sonarqube sonarqube-db nexus
docker rm sonarqube sonarqube-db nexus

# Terminate EC2 instances
```

---

**Congratulations! Your CI/CD pipeline is now complete and operational.**
