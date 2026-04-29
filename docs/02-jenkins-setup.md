# Jenkins Setup and Configuration

## Server Requirements

### Recommended Instance Sizing

**Minimum Requirements:**
- Instance Type: `t3.medium` (2 vCPU, 4GB RAM)
- Storage: 30GB SSD minimum
- OS: Ubuntu 22.04 LTS

**Production Recommendations:**
- Instance Type: `t3.large` or `t3.xlarge` for heavy workloads
- Storage: 50-100GB SSD
- Reason: Jenkins is CPU and memory intensive during builds, Docker operations, and parallel pipeline execution

**Why Not Identical Servers:**
- Jenkins has higher CPU requirements than Nexus
- Build processes are resource-intensive
- Requires more memory for concurrent builds
- Docker operations consume significant resources

### Cost Considerations

**Separate Server (Recommended):**
- Better isolation and security
- Independent scaling based on build load
- No resource contention with other tools
- Easier troubleshooting and maintenance

**Combined Setup (Dev/Test Only):**
- Can run on shared t3.large (2 vCPU, 8GB RAM) with SonarQube and Nexus
- Use Docker containers for isolation
- Monitor resource usage carefully
- Not recommended for production

## 1. Install Jenkins on EC2

### Launch EC2 Instance

```bash
# Launch Ubuntu 22.04 instance (t3.medium or larger recommended)
# Security Group: Allow ports 22, 8080, 50000

# SSH into instance
ssh -i your-key.pem ubuntu@your-instance-ip
```

### Install Jenkins

```bash
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

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Install Maven

```bash
sudo apt install -y maven

# Verify installation
mvn -version
```

### Install AWS CLI and kubectl

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
aws --version
kubectl version --client
```

### Install Trivy (Container Security Scanner)

Trivy scans Docker images for vulnerabilities and is used in the Jenkins pipeline.

```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Verify installation
trivy --version
```

**Why on Jenkins Server?**
- Trivy scans Docker images during the build process
- Jenkins builds the Docker images, so Trivy needs to be on the same server
- Scans happen before pushing images to Nexus/Docker registry

## 2. Configure Jenkins

### Access Jenkins

1. Open browser: `http://your-instance-ip:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user

### Install Required Plugins

Navigate to: Manage Jenkins → Manage Plugins → Available

Install these plugins:
- Pipeline
- Git
- Maven Integration
- Docker Pipeline
- Kubernetes
- AWS Steps
- SonarQube Scanner
- Nexus Artifact Uploader
- Blue Ocean (optional)
- Pipeline: AWS Steps

### Configure Global Tools

Navigate to: Manage Jenkins → Global Tool Configuration

#### Maven Configuration
- Name: `Maven-3.9`
- Install automatically: Yes
- Version: 3.9.x

#### JDK Configuration
- Name: `JDK-17`
- JAVA_HOME: `/usr/lib/jvm/java-17-openjdk-amd64`

## 3. Configure Credentials

Navigate to: Manage Jenkins → Manage Credentials → Global

### Add AWS Credentials

1. Click "Add Credentials"
2. Kind: AWS Credentials
3. ID: `aws-credentials`
4. Access Key ID: Your AWS access key
5. Secret Access Key: Your AWS secret key

### Add Docker Registry Credentials

1. Kind: Username with password
2. ID: `docker-credentials`
3. Username: Your Docker Hub username
4. Password: Your Docker Hub password

### Add Docker Registry URL

1. Kind: Secret text
2. ID: `docker-registry-url`
3. Secret: `docker.io/your-username` (or ECR URL)

### Add SonarQube Token

1. Kind: Secret text
2. ID: `sonarqube-token`
3. Secret: Your SonarQube token (generate in SonarQube)

### Add Nexus Credentials

1. Kind: Username with password
2. ID: `nexus-credentials`
3. Username: admin
4. Password: Your Nexus password

### Add GitHub Credentials

1. Kind: Username with password (or SSH key)
2. ID: `github-credentials`
3. Username: Your GitHub username
4. Password: Personal Access Token

## 4. Configure AWS on Jenkins

```bash
# SSH into Jenkins server
sudo su - jenkins

# Configure AWS CLI
aws configure
# Enter your AWS credentials

# Test EKS access
aws eks list-clusters --region us-east-1
```

## 5. Create Jenkins Pipeline Job

1. New Item → Pipeline
2. Name: `springboot-eks-pipeline`
3. Pipeline Definition: Pipeline script from SCM
4. SCM: Git
5. Repository URL: Your GitHub repo URL
6. Credentials: Select github-credentials
7. Branch: `*/main`
8. Script Path: `Jenkinsfile`
9. Save

## 6. Configure GitHub Webhook

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. Payload URL: `http://your-jenkins-ip:8080/github-webhook/`
4. Content type: application/json
5. Events: Just the push event
6. Active: Yes
7. Add webhook

## Security Best Practices

### Enable CSRF Protection
- Manage Jenkins → Configure Global Security
- Enable "Prevent Cross Site Request Forgery exploits"

### Configure Authorization
- Use Matrix-based security or Role-based strategy
- Limit anonymous access

### Secure Jenkins
```bash
# Enable firewall
sudo ufw allow 22
sudo ufw allow 8080
sudo ufw enable

# Use HTTPS (recommended for production)
# Configure reverse proxy with Nginx/Apache
```

### Authentication Integration

For production environments, configure centralized authentication:
- LDAP/Active Directory integration
- OAuth 2.0 / GitHub SSO
- API token management
- Password policies

See [Authentication Integration Guide](07-authentication-integration.md) for detailed setup.

## Next Steps

Proceed to [SonarQube Setup](03-sonarqube-setup.md)
