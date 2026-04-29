# Quick Start Guide

## Choose Your Setup

### Option 1: Separate Servers (Production) ✅ Recommended

**What you get:**
- 3 EC2 instances (Jenkins, SonarQube, Nexus)
- Production-ready architecture
- Better performance and reliability
- Independent scaling

**Cost:** ~$95/month

**Follow these guides:**
1. [Architecture Overview](docs/00-architecture-overview.md) - Understand the setup
2. [Infrastructure Setup](docs/01-infrastructure-setup.md) - AWS prerequisites
3. [Jenkins Setup](docs/02-jenkins-setup.md) - Install on Server 1
4. [SonarQube Setup](docs/03-sonarqube-setup.md) - Install on Server 2
5. [Nexus Setup](docs/04-nexus-setup.md) - Install on Server 3
6. [EKS Setup](docs/05-eks-setup.md) - Kubernetes cluster
7. [Pipeline Deployment](docs/06-pipeline-deployment.md) - Deploy your app
8. [Authentication](docs/07-authentication-integration.md) - Secure everything

---

### Option 2: Combined Server (Dev/Test) 💡 Budget-Friendly

**What you get:**
- 1 EC2 instance running all tools in Docker
- Lower cost for learning/testing
- Simpler management
- Not suitable for production

**Cost:** ~$80/month

**Follow this guide:**
1. [Combined Server Setup](docs/08-combined-server-setup.md) - Complete setup in one place

---

## Server Requirements Summary

### Separate Servers

| Server | Instance Type | vCPU | RAM | Storage | Monthly Cost |
|--------|---------------|------|-----|---------|--------------|
| Jenkins | t3.medium | 2 | 4GB | 50-100GB | ~$30 |
| SonarQube | t3.medium | 2 | 4GB | 50GB | ~$30 |
| Nexus | t3.small | 2 | 2GB | 100-500GB | ~$15 |

### Combined Server

| Server | Instance Type | vCPU | RAM | Storage | Monthly Cost |
|--------|---------------|------|-----|---------|--------------|
| All-in-One | t3.large | 2 | 8GB | 200GB | ~$60 |

---

## What Each Tool Does

### Jenkins (CI/CD Server)
- Orchestrates the entire pipeline
- Builds your code with Maven
- Runs tests
- Builds Docker images
- **Scans Docker images with Trivy** (installed on Jenkins server)
- Deploys to Kubernetes

**Access:** `http://jenkins-server:8080`

**Installed Tools:**
- Java, Maven, Docker, kubectl, AWS CLI, Trivy

### SonarQube (Code Quality)
- Analyzes code for bugs
- Measures code coverage
- Detects security vulnerabilities
- Enforces quality standards

**Access:** `http://sonarqube-server:9000`

### Nexus (Artifact Storage)
- Stores Maven artifacts (JAR files)
- Hosts Docker images
- Proxies Maven Central
- Manages releases and snapshots

**Access:** `http://nexus-server:8081`

---

## Pipeline Flow

```
1. Developer pushes code to GitHub
         ↓
2. Jenkins detects change (webhook)
         ↓
3. Jenkins builds with Maven
         ↓
4. Jenkins sends code to SonarQube for analysis
         ↓
5. SonarQube returns quality gate status
         ↓
6. Jenkins builds Docker image
         ↓
7. Jenkins scans image with Trivy (security vulnerabilities)
         ↓
8. Jenkins pushes artifact to Nexus
         ↓
9. Jenkins deploys to AWS EKS
         ↓
10. Application runs in Kubernetes
```

---

## Prerequisites

Before starting, you need:

- ✅ AWS account with admin access
- ✅ GitHub account
- ✅ Docker Hub account (or use AWS ECR)
- ✅ Basic knowledge of Linux commands
- ✅ SSH key pair for EC2 access
- ✅ Credit card for AWS (free tier available)

**Windows Users:** All AWS commands are available in PowerShell - see [Windows PowerShell Guide](docs/windows-powershell-guide.md)

---

## Time Estimate

### Separate Servers Setup
- Infrastructure: 1-2 hours
- Jenkins: 1-2 hours
- SonarQube: 30 minutes
- Nexus: 30 minutes
- EKS: 1 hour
- Pipeline: 1 hour
- **Total: 5-7 hours**

### Combined Server Setup
- Server setup: 30 minutes
- Tool installation: 1 hour
- Configuration: 1-2 hours
- **Total: 2.5-3.5 hours**

---

## Common Questions

### Q: Can I use the combined server for production?
**A:** No, it's not recommended. Use separate servers for production to avoid resource contention and single point of failure.

### Q: Can I start with combined and migrate later?
**A:** Yes! Start with the combined setup for learning, then migrate to separate servers when ready. Backup and restore procedures are included.

### Q: Do I need all three tools?
**A:** For a complete CI/CD pipeline, yes. But you can start with just Jenkins and add SonarQube/Nexus later.

### Q: What if I already have Jenkins/SonarQube/Nexus?
**A:** You can integrate existing installations. Just update the URLs in Jenkins configuration.

### Q: Can I use different instance types?
**A:** Yes, but don't go below the minimum requirements. You can scale up based on your workload.

---

## Getting Help

- Check the detailed guides in the `docs/` folder
- Review the [Architecture Overview](docs/00-architecture-overview.md) for diagrams
- See [Troubleshooting](#troubleshooting) section below

---

## Troubleshooting

### Jenkins won't start
```bash
# Check logs
sudo journalctl -u jenkins -f

# Check if port 8080 is in use
sudo netstat -tulpn | grep 8080
```

### SonarQube fails to start
```bash
# Check Elasticsearch requirements
sysctl vm.max_map_count
# Should be 262144

# Fix if needed
sudo sysctl -w vm.max_map_count=262144
```

### Nexus is slow
```bash
# Check disk space
df -h

# Check memory
free -h

# Increase memory if needed
```

### Can't connect between tools
```bash
# Check security groups (AWS)
# Ensure ports are open between servers

# Test connectivity
curl http://sonarqube-server:9000
curl http://nexus-server:8081
```

---

## Next Steps After Setup

1. ✅ Change all default passwords
2. ✅ Configure HTTPS (production)
3. ✅ Set up authentication (LDAP/OAuth)
4. ✅ Configure backups
5. ✅ Set up monitoring
6. ✅ Create your first pipeline
7. ✅ Test the complete flow

---

## Support

For detailed instructions, see the full documentation in the `docs/` folder.

**Documentation Index:**
- [00-architecture-overview.md](docs/00-architecture-overview.md) - Architecture and design
- [01-infrastructure-setup.md](docs/01-infrastructure-setup.md) - AWS setup
- [02-jenkins-setup.md](docs/02-jenkins-setup.md) - Jenkins installation
- [03-sonarqube-setup.md](docs/03-sonarqube-setup.md) - SonarQube installation
- [04-nexus-setup.md](docs/04-nexus-setup.md) - Nexus installation
- [05-eks-setup.md](docs/05-eks-setup.md) - Kubernetes setup
- [06-pipeline-deployment.md](docs/06-pipeline-deployment.md) - Pipeline creation
- [07-authentication-integration.md](docs/07-authentication-integration.md) - Security
- [08-combined-server-setup.md](docs/08-combined-server-setup.md) - All-in-one setup
