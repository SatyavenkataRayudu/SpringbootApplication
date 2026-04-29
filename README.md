# Spring Boot CI/CD Pipeline with AWS EKS

Complete CI/CD pipeline for deploying a Spring Boot application to AWS EKS using Jenkins, Maven, Docker, Trivy, SonarQube, Nexus, and AWS S3.

> **👋 New to this setup?** Start with the [Quick Start Guide](QUICK_START.md) to choose between separate servers (production) or combined server (dev/test).

## Architecture Overview

- **Source Control**: GitHub
- **Build Tool**: Maven
- **CI/CD**: Jenkins
- **Security Scanning**: Trivy (container scanning), SonarQube (code quality)
- **Artifact Repository**: Nexus
- **Container Registry**: Docker Hub / AWS ECR
- **Backup Storage**: AWS S3
- **Deployment Target**: AWS EKS

## Prerequisites

- AWS Account with appropriate permissions
- GitHub account
- Docker Hub account (or AWS ECR)
- Domain name (optional, for ingress)
- **Windows Users**: See [Windows PowerShell Guide](docs/windows-powershell-guide.md) for PowerShell commands

## Architecture

This setup uses **3 separate EC2 instances** (one for each tool):
- **Jenkins Server** (t3.medium): CI/CD orchestration, builds, deployments
- **SonarQube Server** (t3.medium): Code quality analysis
- **Nexus Server** (t3.small): Artifact and Docker image storage

**Alternative for Dev/Test:** Run all tools on a single t3.large instance - see [Combined Server Setup](docs/08-combined-server-setup.md)

See [Architecture Overview](docs/00-architecture-overview.md) for detailed diagrams, network configuration, and cost comparison.

## Quick Start

**Choose your setup:**
- **Production:** Follow guides 0-7 below for separate servers
- **Dev/Test:** Use [Combined Server Setup](docs/08-combined-server-setup.md) for all-in-one installation

**Separate servers setup (recommended for production):**

0. [Architecture Overview](docs/00-architecture-overview.md) - **START HERE** to understand the setup
1. [Infrastructure Setup](docs/01-infrastructure-setup.md)
2. [Jenkins Configuration](docs/02-jenkins-setup.md)
3. [SonarQube Setup](docs/03-sonarqube-setup.md) - Docker or [Native Installation](docs/03-sonarqube-setup-native.md)
4. [Nexus Setup](docs/04-nexus-setup.md) - Docker or [Native Installation](docs/04-nexus-setup-native.md)
5. [AWS EKS Setup](docs/05-eks-setup.md)
6. [Pipeline Deployment](docs/06-pipeline-deployment.md)
7. [Authentication Integration](docs/07-authentication-integration.md) - Security best practices

## Project Structure

```
.
├── src/                          # Spring Boot application source
├── k8s/                          # Kubernetes manifests
├── jenkins/                      # Jenkins pipeline files
├── terraform/                    # Infrastructure as Code (optional)
├── docs/                         # Detailed documentation
│   ├── 00-architecture-overview.md
│   ├── 01-infrastructure-setup.md
│   ├── 02-jenkins-setup.md
│   ├── 03-sonarqube-setup.md
│   ├── 04-nexus-setup.md
│   ├── 05-eks-setup.md
│   ├── 06-pipeline-deployment.md
│   ├── 07-authentication-integration.md
│   ├── 08-combined-server-setup.md
│   └── tool-locations.md        # Where each tool is installed
└── scripts/                      # Utility scripts
```

**Note:** Trivy (container scanner) is installed on the Jenkins server. See [Tool Locations](docs/tool-locations.md) for details.

## Pipeline Flow

1. Code push to GitHub
2. Jenkins webhook triggers pipeline
3. Maven build and unit tests
4. SonarQube code quality analysis
5. Trivy security scan
6. Docker image build
7. Push to Nexus/Docker registry
8. Backup artifacts to S3
9. Deploy to AWS EKS
10. Health check verification

## Security Features

- **Centralized Authentication**: LDAP/Active Directory or OAuth 2.0 integration
- **API Token Management**: Secure service account authentication
- **Role-Based Access Control**: Group-based permissions across all tools
- **Secrets Management**: Jenkins credentials plugin and AWS Secrets Manager
- **Audit Logging**: Complete audit trail for compliance
- **Network Security**: HTTPS/TLS, firewall rules, VPC isolation
- **Container Scanning**: Trivy for vulnerability detection
- **Code Quality Gates**: SonarQube quality enforcement

See [Authentication Integration Guide](docs/07-authentication-integration.md) for detailed security setup.
