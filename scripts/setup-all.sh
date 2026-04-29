#!/bin/bash

# Complete setup script for CI/CD pipeline
# Run this script to set up the entire infrastructure

set -e

echo "========================================="
echo "CI/CD Pipeline Setup Script"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run as root"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_info "Checking prerequisites..."

MISSING_TOOLS=()

if ! command_exists aws; then
    MISSING_TOOLS+=("aws-cli")
fi

if ! command_exists kubectl; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command_exists eksctl; then
    MISSING_TOOLS+=("eksctl")
fi

if ! command_exists helm; then
    MISSING_TOOLS+=("helm")
fi

if ! command_exists docker; then
    MISSING_TOOLS+=("docker")
fi

if ! command_exists mvn; then
    MISSING_TOOLS+=("maven")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    print_error "Missing required tools: ${MISSING_TOOLS[*]}"
    print_info "Please install missing tools and run again"
    exit 1
fi

print_info "All prerequisites met!"

# Get user inputs
print_info "Please provide the following information:"

read -p "AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "EKS Cluster Name (default: my-eks-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-my-eks-cluster}

read -p "S3 Bucket Name for artifacts: " S3_BUCKET
if [ -z "$S3_BUCKET" ]; then
    print_error "S3 bucket name is required"
    exit 1
fi

read -p "Docker Registry (docker.io/username or ECR URL): " DOCKER_REGISTRY
if [ -z "$DOCKER_REGISTRY" ]; then
    print_error "Docker registry is required"
    exit 1
fi

read -p "GitHub Repository URL: " GITHUB_REPO
if [ -z "$GITHUB_REPO" ]; then
    print_error "GitHub repository URL is required"
    exit 1
fi

# Confirm
echo ""
print_warning "Please confirm the following settings:"
echo "AWS Region: $AWS_REGION"
echo "EKS Cluster: $CLUSTER_NAME"
echo "S3 Bucket: $S3_BUCKET"
echo "Docker Registry: $DOCKER_REGISTRY"
echo "GitHub Repo: $GITHUB_REPO"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Setup cancelled"
    exit 0
fi

# Create S3 bucket
print_info "Creating S3 bucket..."
if aws s3 mb s3://$S3_BUCKET --region $AWS_REGION 2>/dev/null; then
    print_info "S3 bucket created successfully"
else
    print_warning "S3 bucket might already exist or creation failed"
fi

# Enable S3 versioning
print_info "Enabling S3 versioning..."
aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET \
    --versioning-configuration Status=Enabled \
    --region $AWS_REGION

# Create EKS cluster
print_info "Creating EKS cluster (this will take 15-20 minutes)..."
cat > /tmp/eks-cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $AWS_REGION
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
    privateNetworking: true

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
EOF

eksctl create cluster -f /tmp/eks-cluster-config.yaml

# Update kubeconfig
print_info "Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Install AWS Load Balancer Controller
print_info "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME

# Install Metrics Server
print_info "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create production namespace
print_info "Creating production namespace..."
kubectl create namespace production

# Create Docker registry secret
print_info "Creating Docker registry secret..."
read -sp "Docker Registry Password: " DOCKER_PASSWORD
echo ""

kubectl create secret docker-registry docker-registry-secret \
    --docker-server=$(echo $DOCKER_REGISTRY | cut -d'/' -f1) \
    --docker-username=$(echo $DOCKER_REGISTRY | cut -d'/' -f2) \
    --docker-password=$DOCKER_PASSWORD \
    -n production

# Update configuration files
print_info "Updating configuration files..."

# Update Jenkinsfile
sed -i "s|DOCKER_REGISTRY = .*|DOCKER_REGISTRY = '$DOCKER_REGISTRY'|g" Jenkinsfile
sed -i "s|AWS_REGION = .*|AWS_REGION = '$AWS_REGION'|g" Jenkinsfile
sed -i "s|EKS_CLUSTER_NAME = .*|EKS_CLUSTER_NAME = '$CLUSTER_NAME'|g" Jenkinsfile
sed -i "s|S3_BUCKET = .*|S3_BUCKET = '$S3_BUCKET'|g" Jenkinsfile

print_info "Setup completed successfully!"
echo ""
print_info "Next steps:"
echo "1. Set up Jenkins server (see docs/02-jenkins-setup.md)"
echo "2. Set up SonarQube (see docs/03-sonarqube-setup.md)"
echo "3. Set up Nexus (see docs/04-nexus-setup.md)"
echo "4. Configure Jenkins pipeline (see docs/06-pipeline-deployment.md)"
echo ""
print_info "Cluster information:"
kubectl cluster-info
echo ""
print_info "Nodes:"
kubectl get nodes
