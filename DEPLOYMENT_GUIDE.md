# Complete Deployment Guide

## Overview

This guide provides step-by-step instructions to deploy a Spring Boot application to AWS EKS using a complete CI/CD pipeline with Jenkins, Maven, Docker, Trivy, SonarQube, Nexus, and AWS S3.

## Architecture

```
GitHub → Jenkins → Maven Build → SonarQube → Trivy Scan → Docker → Nexus → AWS S3 → AWS EKS
```

## Prerequisites

- AWS Account with appropriate permissions
- GitHub account
- Docker Hub account (or AWS ECR)
- Domain name (optional, for ingress)
- Basic knowledge of Kubernetes, Docker, and CI/CD

## Quick Start (Automated)

```bash
# Clone repository
git clone https://github.com/your-username/springboot-eks-cicd.git
cd springboot-eks-cicd

# Make setup script executable
chmod +x scripts/setup-all.sh

# Run automated setup
./scripts/setup-all.sh
```

## Manual Setup (Step by Step)

### Step 1: Infrastructure Setup (30 minutes)

Follow: [docs/01-infrastructure-setup.md](docs/01-infrastructure-setup.md)

- Install required tools (AWS CLI, kubectl, eksctl, helm)
- Configure AWS credentials
- Create S3 bucket for artifacts
- Create IAM roles and policies

### Step 2: Jenkins Setup (45 minutes)

Follow: [docs/02-jenkins-setup.md](docs/02-jenkins-setup.md)

- Launch EC2 instance for Jenkins
- Install Jenkins, Docker, Maven
- Configure Jenkins plugins
- Set up credentials
- Configure GitHub webhook

### Step 3: SonarQube Setup (20 minutes)

Follow: [docs/03-sonarqube-setup.md](docs/03-sonarqube-setup.md)

- Install SonarQube using Docker
- Configure quality gates
- Create authentication token
- Integrate with Jenkins

### Step 4: Nexus Setup (20 minutes)

Follow: [docs/04-nexus-setup.md](docs/04-nexus-setup.md)

- Install Nexus using Docker
- Create Maven repositories
- Configure Docker registry
- Set up Maven settings.xml

### Step 5: AWS EKS Setup (60 minutes)

Follow: [docs/05-eks-setup.md](docs/05-eks-setup.md)

- Create EKS cluster using eksctl
- Install AWS Load Balancer Controller
- Install Metrics Server
- Configure kubectl access
- Set up monitoring (optional)

### Step 6: Pipeline Deployment (30 minutes)

Follow: [docs/06-pipeline-deployment.md](docs/06-pipeline-deployment.md)

- Configure Jenkins pipeline
- Update configuration files
- Run first build
- Verify deployment
- Set up automatic deployments

## Total Setup Time

- Automated: ~2 hours (mostly waiting for EKS cluster)
- Manual: ~3-4 hours (including learning and troubleshooting)

## Project Structure

```
.
├── src/                              # Spring Boot application
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   └── test/
├── k8s/                              # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── serviceaccount.yaml
│   └── hpa.yaml
├── docs/                             # Documentation
│   ├── 01-infrastructure-setup.md
│   ├── 02-jenkins-setup.md
│   ├── 03-sonarqube-setup.md
│   ├── 04-nexus-setup.md
│   ├── 05-eks-setup.md
│   └── 06-pipeline-deployment.md
├── scripts/                          # Utility scripts
│   ├── setup-all.sh
│   ├── deploy-local.sh
│   └── cleanup.sh
├── Dockerfile                        # Multi-stage Docker build
├── Jenkinsfile                       # CI/CD pipeline definition
├── pom.xml                          # Maven configuration
└── README.md                        # Project overview
```

## Pipeline Stages

1. **Checkout** - Clone code from GitHub
2. **Build** - Compile Java application with Maven
3. **Unit Tests** - Run tests with JaCoCo coverage
4. **SonarQube Analysis** - Code quality and security analysis
5. **Quality Gate** - Wait for SonarQube quality gate result
6. **Package** - Create JAR file
7. **Publish to Nexus** - Upload artifact to Nexus repository
8. **Build Docker Image** - Create container image
9. **Trivy Security Scan** - Scan Docker image for vulnerabilities
10. **Push Docker Image** - Push to Docker registry
11. **Backup to S3** - Store artifacts in AWS S3
12. **Update K8s Manifests** - Update deployment files with new image tag
13. **Deploy to EKS** - Deploy to Kubernetes cluster
14. **Health Check** - Verify deployment success

## Key Features

### Security
- Trivy container scanning
- SonarQube code analysis
- Non-root container user
- Pod security contexts
- Network policies (optional)
- Secrets management

### High Availability
- 3 replicas by default
- Rolling update strategy
- Liveness and readiness probes
- Pod disruption budgets
- Multi-AZ deployment

### Scalability
- Horizontal Pod Autoscaler (HPA)
- Cluster Autoscaler
- Resource requests and limits
- Efficient resource utilization

### Monitoring
- Prometheus metrics
- Grafana dashboards
- CloudWatch Container Insights
- Application health endpoints

### Backup & Recovery
- S3 artifact backup
- Velero cluster backup
- Database backups (if applicable)
- Disaster recovery procedures

## Testing

### Local Testing

```bash
# Build and run locally
./scripts/deploy-local.sh

# Test endpoints
curl http://localhost:8080
curl http://localhost:8080/actuator/health
```

### Pipeline Testing

```bash
# Trigger manual build
# Jenkins → springboot-eks-pipeline → Build Now

# Monitor deployment
kubectl get pods -n production -w
```

### Load Testing

```bash
# Install hey
go install github.com/rakyll/hey@latest

# Run load test
hey -z 2m -c 50 http://your-alb-url/

# Watch auto-scaling
kubectl get hpa -n production -w
```

## Monitoring

### Application Metrics

```bash
# Prometheus metrics
curl http://your-alb-url/actuator/prometheus

# Health check
curl http://your-alb-url/actuator/health
```

### Kubernetes Metrics

```bash
# Pod metrics
kubectl top pods -n production

# Node metrics
kubectl top nodes

# HPA status
kubectl get hpa -n production
```

### Logs

```bash
# Application logs
kubectl logs -f deployment/springboot-app -n production

# All pods logs
kubectl logs -l app=springboot-app -n production --tail=100

# CloudWatch logs
aws logs tail /aws/eks/my-eks-cluster/cluster --follow
```

## Troubleshooting

### Common Issues

1. **Pipeline fails at SonarQube stage**
   - Check SonarQube is running: `docker ps | grep sonarqube`
   - Verify token in Jenkins credentials

2. **Docker push fails**
   - Verify Docker credentials in Jenkins
   - Test manual push: `docker push your-registry/test`

3. **EKS deployment fails**
   - Check kubectl access: `kubectl get nodes`
   - Update kubeconfig: `aws eks update-kubeconfig --name cluster-name`

4. **Pods not starting**
   - Check pod status: `kubectl describe pod <pod-name> -n production`
   - Check events: `kubectl get events -n production`

5. **Ingress not working**
   - Check ALB controller: `kubectl get pods -n kube-system | grep aws-load-balancer`
   - Check ingress: `kubectl describe ingress -n production`

## Cost Optimization

### Estimated Monthly Costs (us-east-1)

- EKS Cluster: ~$73/month
- EC2 Nodes (3x t3.medium): ~$90/month
- ALB: ~$20/month
- S3 Storage: ~$5/month
- Data Transfer: Variable
- **Total: ~$190-250/month**

### Cost Saving Tips

1. Use Spot Instances for worker nodes
2. Enable cluster autoscaler
3. Set up pod autoscaling
4. Use S3 lifecycle policies
5. Delete unused resources
6. Use AWS Cost Explorer

## Security Best Practices

1. Enable pod security standards
2. Use network policies
3. Implement RBAC properly
4. Rotate credentials regularly
5. Enable audit logging
6. Use AWS Secrets Manager
7. Scan images regularly
8. Keep dependencies updated
9. Use HTTPS/TLS everywhere
10. Implement least privilege access

## Cleanup

To remove all resources:

```bash
# Run cleanup script
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh

# Or manually:
# 1. Delete EKS cluster
eksctl delete cluster --name my-eks-cluster --region us-east-1

# 2. Delete S3 bucket
aws s3 rb s3://my-artifacts-bucket --force

# 3. Terminate Jenkins EC2 instance
# 4. Stop Docker containers (SonarQube, Nexus)
```

## Support and Resources

### Documentation
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)

### Tools
- [eksctl](https://eksctl.io/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Helm](https://helm.sh/)
- [Trivy](https://aquasecurity.github.io/trivy/)

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.

## Acknowledgments

- Spring Boot team
- Kubernetes community
- AWS EKS team
- Jenkins community
- All open-source contributors
