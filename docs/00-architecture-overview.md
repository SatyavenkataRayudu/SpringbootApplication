# Architecture Overview

## Infrastructure Layout

### Separate Server Architecture (Recommended)

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐│
│  │  Jenkins Server  │  │ SonarQube Server │  │  Nexus Server  ││
│  │   EC2 Instance   │  │   EC2 Instance   │  │  EC2 Instance  ││
│  │                  │  │                  │  │                ││
│  │  t3.medium       │  │  t3.medium       │  │  t3.small      ││
│  │  2 vCPU, 4GB RAM │  │  2 vCPU, 4GB RAM │  │  2 vCPU, 2GB   ││
│  │  Port: 8080      │  │  Port: 9000      │  │  Port: 8081    ││
│  │  Port: 50000     │  │                  │  │  Port: 8082    ││
│  │                  │  │                  │  │                ││
│  │  - Build jobs    │  │  - Code analysis │  │  - Maven repo  ││
│  │  - Run tests     │  │  - Quality gates │  │  - Docker repo ││
│  │  - Docker build  │  │  - Security scan │  │  - Artifacts   ││
│  │  - Trivy scan    │  │  - Tech debt     │  │                ││
│  │  - Deploy to EKS │  │                  │  │                ││
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬───────┘│
│           │                     │                      │        │
│           └─────────────────────┴──────────────────────┘        │
│                              │                                   │
│                    ┌─────────▼──────────┐                       │
│                    │   AWS EKS Cluster  │                       │
│                    │  (Kubernetes)      │                       │
│                    │                    │                       │
│                    │  - Spring Boot App │                       │
│                    │  - Auto-scaling    │                       │
│                    │  - Load Balancer   │                       │
│                    └────────────────────┘                       │
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │   AWS S3 Bucket  │         │   AWS ECR        │             │
│  │  (Artifacts)     │         │  (Docker Images) │             │
│  └──────────────────┘         └──────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Server Configuration Details

### Server 1: Jenkins (CI/CD Orchestrator)

**Instance Details:**
- EC2 Instance Type: `t3.medium` (2 vCPU, 4GB RAM)
- Storage: 50-100GB SSD
- OS: Ubuntu 22.04 LTS
- IP: `10.0.1.10` (example private IP)
- Public IP: Elastic IP or ALB

**Installed Software:**
- Jenkins (port 8080)
- Java 17
- Maven
- Docker
- AWS CLI
- kubectl
- **Trivy** (container security scanner)

**Purpose:**
- Orchestrates the entire CI/CD pipeline
- Builds Maven projects
- Runs unit tests
- Builds Docker images
- **Scans Docker images with Trivy** (security vulnerabilities)
- Triggers SonarQube analysis
- Pushes artifacts to Nexus
- Deploys to EKS cluster

**Network Access:**
- Inbound: 8080 (Jenkins UI), 50000 (agent communication), 22 (SSH)
- Outbound: Internet, SonarQube (9000), Nexus (8081, 8082), EKS API

---

### Server 2: SonarQube (Code Quality Analysis)

**Instance Details:**
- EC2 Instance Type: `t3.medium` (2 vCPU, 4GB RAM)
- Storage: 50GB SSD
- OS: Ubuntu 22.04 LTS
- IP: `10.0.1.20` (example private IP)
- Public IP: Elastic IP or ALB

**Installed Software:**
- SonarQube (port 9000)
- PostgreSQL (Docker container)
- Elasticsearch (embedded in SonarQube)

**Purpose:**
- Analyzes code quality
- Detects bugs and vulnerabilities
- Measures code coverage
- Enforces quality gates
- Tracks technical debt

**Network Access:**
- Inbound: 9000 (SonarQube UI), 22 (SSH)
- Outbound: Internet (for updates), Jenkins (webhook callback)

**Special Configuration:**
- Requires `vm.max_map_count=262144` for Elasticsearch
- PostgreSQL database for persistence

---

### Server 3: Nexus (Artifact Repository)

**Instance Details:**
- EC2 Instance Type: `t3.small` (2 vCPU, 2GB RAM)
- Storage: 100-500GB SSD (grows with artifacts)
- OS: Ubuntu 22.04 LTS
- IP: `10.0.1.30` (example private IP)
- Public IP: Elastic IP or ALB

**Installed Software:**
- Nexus Repository Manager (port 8081)
- Docker Registry (port 8082)

**Purpose:**
- Stores Maven artifacts (JAR, WAR files)
- Hosts Docker images
- Proxies Maven Central
- Manages release and snapshot repositories

**Network Access:**
- Inbound: 8081 (Nexus UI/Maven), 8082 (Docker registry), 22 (SSH)
- Outbound: Internet (Maven Central proxy), Jenkins (for pulls)

**Storage Growth:**
- Maven artifacts: 10-50GB initially
- Docker images: Can grow to 100GB+
- Requires cleanup policies

---

## Communication Flow

```
Developer Push to GitHub
         │
         ▼
    Jenkins Server ──────────────┐
         │                       │
         │ 1. Checkout code      │
         │ 2. Maven build        │
         │                       │
         ├──────────────────────►│ SonarQube Server
         │ 3. Send code for      │      │
         │    analysis           │      │ Analyze & return
         │◄──────────────────────┤      │ quality gate status
         │                       │      │
         │ 4. Build Docker image │      │
         │ 5. Scan with Trivy    │      │
         │    (on Jenkins)       │      │
         │                       │      │
         ├──────────────────────►│ Nexus Server
         │ 6. Push artifact      │      │
         │    and Docker image   │      │
         │                       │      │
         │ 7. Deploy to EKS      │      │
         ▼                       │      │
    EKS Cluster                  │      │
         │                       │      │
         │ 8. Pull image from ───┘      │
         │    Nexus/ECR                 │
         │                              │
         ▼                              │
    Running Application                 │
```

## Why Separate Servers?

### Advantages

1. **Resource Isolation**
   - Jenkins builds don't impact SonarQube analysis
   - Nexus storage doesn't affect Jenkins performance
   - Each tool gets dedicated resources

2. **Security**
   - Different security groups per tool
   - Isolated credentials and secrets
   - Principle of least privilege
   - Easier to audit and monitor

3. **Scalability**
   - Scale each tool independently
   - Jenkins: Add more CPU for builds
   - SonarQube: Add more memory for analysis
   - Nexus: Add more storage for artifacts

4. **Maintenance**
   - Update/restart one tool without affecting others
   - Easier troubleshooting
   - Independent backup schedules
   - Reduced blast radius for failures

5. **High Availability**
   - One tool failure doesn't bring down others
   - Can implement HA for critical tools
   - Better disaster recovery

### Cost Comparison

**Separate Servers (Production):**
```
Jenkins:   t3.medium  ($30/month)
SonarQube: t3.medium  ($30/month)
Nexus:     t3.small   ($15/month)
Storage:   200GB EBS  ($20/month)
─────────────────────────────────
Total:                ~$95/month
```

**Combined Server (Dev/Test Only):**
```
Single:    t3.large   ($60/month)
Storage:   200GB EBS  ($20/month)
─────────────────────────────────
Total:                ~$80/month

Savings: $15/month (16%)
Trade-offs: Less reliable, resource contention, not production-ready
```

## Alternative: Combined Server Setup

If you need to run all tools on one server (development/testing only), see the complete guide: [Combined Server Setup](08-combined-server-setup.md)

Quick overview:

```
┌─────────────────────────────────────────┐
│     Single EC2 Instance (t3.large)      │
│         2 vCPU, 8GB RAM                 │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Docker Container: Jenkins      │   │
│  │  Port: 8080, 50000              │   │
│  │  Memory: 3GB                    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Docker Container: SonarQube    │   │
│  │  Port: 9000                     │   │
│  │  Memory: 3GB                    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Docker Container: Nexus        │   │
│  │  Port: 8081, 8082               │   │
│  │  Memory: 2GB                    │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Setup Script for Combined Server:**

```bash
#!/bin/bash
# Run all tools on single server (dev/test only)

# Create Docker network
docker network create cicd-network

# Run PostgreSQL for SonarQube
docker run -d \
  --name sonarqube-db \
  --network cicd-network \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  postgres:15-alpine

# Run SonarQube
docker run -d \
  --name sonarqube \
  --network cicd-network \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  --memory="3g" \
  sonarqube:lts-community

# Run Nexus
docker run -d \
  --name nexus \
  --network cicd-network \
  -p 8081:8081 \
  -p 8082:8082 \
  --memory="2g" \
  sonatype/nexus3:latest

# Run Jenkins
docker run -d \
  --name jenkins \
  --network cicd-network \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --memory="3g" \
  jenkins/jenkins:lts
```

## Network Configuration

### Security Groups (AWS)

**Jenkins Security Group:**
```
Inbound:
- Port 8080 (HTTP) from 0.0.0.0/0 or ALB
- Port 50000 (Agent) from agent IPs
- Port 22 (SSH) from your IP only

Outbound:
- All traffic (for GitHub, SonarQube, Nexus, EKS)
```

**SonarQube Security Group:**
```
Inbound:
- Port 9000 (HTTP) from Jenkins SG and 0.0.0.0/0 or ALB
- Port 22 (SSH) from your IP only

Outbound:
- Port 8080 to Jenkins (webhook callbacks)
- Port 443 (HTTPS) for updates
```

**Nexus Security Group:**
```
Inbound:
- Port 8081 (HTTP) from Jenkins SG and 0.0.0.0/0 or ALB
- Port 8082 (Docker) from Jenkins SG and EKS nodes
- Port 22 (SSH) from your IP only

Outbound:
- Port 443 (HTTPS) for Maven Central proxy
```

## DNS Configuration (Optional but Recommended)

```
jenkins.yourdomain.com   → Jenkins Server IP
sonarqube.yourdomain.com → SonarQube Server IP
nexus.yourdomain.com     → Nexus Server IP
docker.yourdomain.com    → Nexus Docker Registry (port 8082)
```

## Monitoring and Logging

Each server should have:
- CloudWatch agent for metrics
- CloudWatch Logs for application logs
- Disk space monitoring
- CPU/Memory alerts
- Backup automation

## Summary

**Current Documentation Assumes:**
- ✓ 3 separate EC2 instances (one per tool)
- ✓ Each tool has dedicated resources
- ✓ Production-ready architecture
- ✓ Independent scaling and maintenance

**You Can Also:**
- Run all on one server for dev/test (see combined setup above)
- Use Docker Compose for easier management
- Migrate to separate servers later when needed

## Next Steps

1. Decide on architecture (separate vs combined)
2. Provision EC2 instances
3. Follow setup guides in order:
   - [Infrastructure Setup](01-infrastructure-setup.md)
   - [Jenkins Setup](02-jenkins-setup.md)
   - [SonarQube Setup](03-sonarqube-setup.md)
   - [Nexus Setup](04-nexus-setup.md)
