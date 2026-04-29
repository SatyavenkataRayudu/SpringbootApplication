# Tool Installation Locations

Quick reference for where each tool is installed in the CI/CD pipeline.

## Separate Server Setup (Production)

### Server 1: Jenkins Server (t3.medium)

**Primary Tools:**
- ✅ Jenkins (port 8080, 50000)
- ✅ Java 17
- ✅ Maven
- ✅ Docker
- ✅ **Trivy** (container security scanner)
- ✅ kubectl
- ✅ AWS CLI

**Why Trivy is here:**
- Jenkins builds Docker images
- Trivy scans those images immediately after build
- Scans happen before pushing to registry
- Needs access to local Docker daemon

**Installation Command:**
```bash
# On Jenkins Server
sudo apt-get install -y trivy
```

---

### Server 2: SonarQube Server (t3.medium)

**Primary Tools:**
- ✅ SonarQube (port 9000)
- ✅ PostgreSQL (database)
- ✅ Elasticsearch (embedded)

**Purpose:**
- Code quality analysis
- Security vulnerability detection in source code
- Technical debt tracking

---

### Server 3: Nexus Server (t3.small)

**Primary Tools:**
- ✅ Nexus Repository Manager (port 8081)
- ✅ Docker Registry (port 8082)

**Purpose:**
- Maven artifact storage
- Docker image storage
- Proxy for Maven Central

---

## Tool Interaction Map

```
┌─────────────────────────────────────────────────────────┐
│                    Jenkins Server                        │
│                                                          │
│  ┌──────────┐  ┌──────┐  ┌────────┐  ┌───────────┐    │
│  │  Maven   │  │Docker│  │ Trivy  │  │  kubectl  │    │
│  │  Build   │→ │Build │→ │ Scan   │→ │  Deploy   │    │
│  └──────────┘  └──────┘  └────────┘  └───────────┘    │
│       ↓            ↓          ↓             ↓           │
└───────┼────────────┼──────────┼─────────────┼──────────┘
        │            │          │             │
        ↓            │          │             │
   SonarQube         │          │             │
   (Code Quality)    │          │             │
                     ↓          │             │
                   Nexus        │             │
                (Artifacts)     │             │
                                │             │
                         (Scan Results)       │
                                              ↓
                                          EKS Cluster
```

## Pipeline Stage Breakdown

### Stage 1: Checkout (Jenkins)
- Tool: Git
- Location: Jenkins Server
- Action: Clone repository

### Stage 2: Build (Jenkins)
- Tool: Maven
- Location: Jenkins Server
- Action: Compile code, run unit tests

### Stage 3: Code Analysis (SonarQube)
- Tool: SonarQube Scanner
- Trigger: Jenkins Server
- Analysis: SonarQube Server
- Action: Analyze code quality, detect bugs

### Stage 4: Docker Build (Jenkins)
- Tool: Docker
- Location: Jenkins Server
- Action: Build container image

### Stage 5: Security Scan (Jenkins)
- Tool: **Trivy**
- Location: **Jenkins Server**
- Action: Scan Docker image for vulnerabilities
- Why here: Needs access to freshly built image

### Stage 6: Push Artifacts (Nexus)
- Tool: Maven Deploy Plugin / Docker Push
- Source: Jenkins Server
- Destination: Nexus Server
- Action: Store artifacts and images

### Stage 7: Deploy (EKS)
- Tool: kubectl
- Location: Jenkins Server
- Target: AWS EKS Cluster
- Action: Deploy to Kubernetes

---

## Combined Server Setup (Dev/Test)

All tools run on **one server** (t3.large) in Docker containers:

```
┌─────────────────────────────────────────────────┐
│         Single EC2 Instance (t3.large)          │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Jenkins Container                       │  │
│  │  - Maven, Docker, Trivy, kubectl        │  │
│  │  - Port: 8080, 50000                    │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  SonarQube Container                     │  │
│  │  - Port: 9000                            │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Nexus Container                         │  │
│  │  - Port: 8081, 8082                      │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Trivy Location:** Inside Jenkins Docker container

**Installation:**
```bash
# Enter Jenkins container
docker exec -it jenkins bash

# Install Trivy
apt-get update
apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy
```

---

## Why Trivy is on Jenkins Server

### Technical Reasons

1. **Docker Image Access**
   - Trivy scans Docker images
   - Jenkins builds Docker images
   - Images are local to Jenkins server
   - No need to transfer images elsewhere

2. **Pipeline Efficiency**
   - Scan happens immediately after build
   - No network transfer required
   - Faster feedback loop
   - Fail fast if vulnerabilities found

3. **Resource Optimization**
   - Trivy is lightweight (~50MB)
   - Minimal CPU/memory overhead
   - No need for dedicated server

### Pipeline Logic

```groovy
// Jenkinsfile example
stage('Build Docker Image') {
    steps {
        sh 'docker build -t myapp:${BUILD_NUMBER} .'
    }
}

stage('Security Scan') {
    steps {
        // Trivy scans the local image
        sh 'trivy image myapp:${BUILD_NUMBER}'
    }
}

stage('Push to Registry') {
    steps {
        // Only push if scan passes
        sh 'docker push nexus:8082/myapp:${BUILD_NUMBER}'
    }
}
```

---

## Alternative: Trivy on Other Servers?

### Could Trivy be on SonarQube Server?
❌ **No, not recommended**
- SonarQube analyzes source code, not containers
- Would require transferring Docker images
- Adds unnecessary complexity

### Could Trivy be on Nexus Server?
❌ **No, not recommended**
- Nexus stores images, doesn't build them
- Would scan after push (too late)
- Want to fail before pushing bad images

### Could Trivy be standalone?
⚠️ **Possible but overkill**
- Adds another server to manage
- Increases costs
- Adds network latency
- No real benefit for most use cases

---

## Summary Table

| Tool | Server | Port | Purpose | Why This Location |
|------|--------|------|---------|-------------------|
| Jenkins | Jenkins Server | 8080, 50000 | CI/CD orchestration | Central control point |
| Maven | Jenkins Server | - | Build Java apps | Builds happen on Jenkins |
| Docker | Jenkins Server | - | Build containers | Images built on Jenkins |
| **Trivy** | **Jenkins Server** | **-** | **Scan containers** | **Scans local images** |
| kubectl | Jenkins Server | - | Deploy to K8s | Deploys from Jenkins |
| AWS CLI | Jenkins Server | - | AWS operations | Jenkins interacts with AWS |
| SonarQube | SonarQube Server | 9000 | Code quality | Dedicated analysis server |
| PostgreSQL | SonarQube Server | 5432 | SonarQube DB | Supports SonarQube |
| Nexus | Nexus Server | 8081, 8082 | Artifact storage | Dedicated storage server |

---

## Quick Reference Commands

### Check Trivy Installation

**Separate Servers:**
```bash
# SSH to Jenkins server
ssh -i key.pem ubuntu@jenkins-server-ip

# Check Trivy
trivy --version
```

**Combined Server:**
```bash
# SSH to server
ssh -i key.pem ubuntu@server-ip

# Check Trivy in Jenkins container
docker exec jenkins trivy --version
```

### Test Trivy Scan

```bash
# Scan a test image
trivy image alpine:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL alpine:latest

# Output to JSON
trivy image -f json -o results.json alpine:latest
```

---

## Related Documentation

- [Architecture Overview](00-architecture-overview.md) - Complete architecture
- [Jenkins Setup](02-jenkins-setup.md) - Jenkins and Trivy installation
- [Combined Server Setup](08-combined-server-setup.md) - All-in-one installation
- [Pipeline Deployment](06-pipeline-deployment.md) - Using Trivy in pipeline
