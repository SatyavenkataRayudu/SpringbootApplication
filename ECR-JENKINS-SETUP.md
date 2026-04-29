# AWS ECR Integration with Jenkins - Complete Guide

Complete guide to use AWS ECR (Elastic Container Registry) instead of Docker Hub with Jenkins CI/CD pipeline.

---

## Why Use ECR Instead of Docker Hub?

✅ **Better AWS Integration** - Native integration with EKS, IAM, and other AWS services
✅ **No Rate Limits** - Unlike Docker Hub's pull rate limits
✅ **Private by Default** - More secure, no public exposure
✅ **IAM-Based Authentication** - No need to manage separate credentials
✅ **Encryption** - Images encrypted at rest
✅ **Vulnerability Scanning** - Built-in image scanning
✅ **Cost-Effective** - Pay only for storage used

---

## Part 1: Create ECR Repository

### Step 1: Create ECR Repository via AWS CLI

```bash
# Set variables
AWS_REGION="us-east-1"
REPO_NAME="springboot-app"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repository
aws ecr create-repository \
  --repository-name ${REPO_NAME} \
  --region ${AWS_REGION} \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Get repository URI
ECR_URI=$(aws ecr describe-repositories \
  --repository-names ${REPO_NAME} \
  --region ${AWS_REGION} \
  --query "repositories[0].repositoryUri" \
  --output text)

echo "ECR Repository URI: ${ECR_URI}"
```

### Step 2: Create ECR Repository via AWS Console

1. Go to AWS Console → ECR
2. Click "Create repository"
3. **Repository name:** `springboot-app`
4. **Visibility:** Private
5. **Image scan on push:** ✅ Enabled
6. **Encryption:** AES-256
7. Click "Create repository"
8. Copy the **Repository URI**

---

## Part 2: Configure IAM Permissions for Jenkins

### Option A: Using IAM Role (Recommended for EC2)

#### Create IAM Policy

```bash
# Create policy file
cat > jenkins-ecr-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": "arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/${REPO_NAME}"
    }
  ]
}
EOF

# Create IAM policy
aws iam create-policy \
  --policy-name JenkinsECRPolicy \
  --policy-document file://jenkins-ecr-policy.json

# Get policy ARN
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/JenkinsECRPolicy"
```

#### Attach Policy to Jenkins EC2 Instance Role

```bash
# Get Jenkins instance role name
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Jenkins-Server" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

ROLE_NAME=$(aws ec2 describe-instances \
  --instance-ids ${INSTANCE_ID} \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text | cut -d'/' -f2)

# Attach policy to role
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn ${POLICY_ARN}
```

#### Or Create New Role and Attach to Jenkins Instance

```bash
# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name JenkinsECRRole \
  --assume-role-policy-document file://trust-policy.json

# Attach ECR policy
aws iam attach-role-policy \
  --role-name JenkinsECRRole \
  --policy-arn ${POLICY_ARN}

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name JenkinsECRProfile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name JenkinsECRProfile \
  --role-name JenkinsECRRole

# Attach to Jenkins EC2 instance
aws ec2 associate-iam-instance-profile \
  --instance-id ${INSTANCE_ID} \
  --iam-instance-profile Name=JenkinsECRProfile
```

### Option B: Using AWS Access Keys (Not Recommended)

If you must use access keys:

```bash
# Create IAM user
aws iam create-user --user-name jenkins-ecr-user

# Attach policy
aws iam attach-user-policy \
  --user-name jenkins-ecr-user \
  --policy-arn ${POLICY_ARN}

# Create access keys
aws iam create-access-key --user-name jenkins-ecr-user
```

---

## Part 3: Configure Jenkins Credentials

### Method 1: Using IAM Role (Recommended)

No credentials needed in Jenkins! The EC2 instance role handles authentication automatically.

### Method 2: Using AWS Access Keys

If using access keys, add them to Jenkins:

```
Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Type:** AWS Credentials
- **ID:** `aws-ecr-credentials`
- **Access Key ID:** Your AWS access key
- **Secret Access Key:** Your AWS secret key
- **Description:** AWS ECR credentials

---

## Part 4: Install AWS CLI on Jenkins Server

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@jenkins-server-ip

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version

# Configure (if using access keys)
sudo su - jenkins
aws configure
# Enter access key, secret key, region, output format

# Test ECR access
aws ecr describe-repositories --region us-east-1
```

---

## Part 5: Install ECR Credential Helper (Optional but Recommended)

```bash
# On Jenkins server
sudo su - jenkins

# Install ECR credential helper
sudo apt-get install -y amazon-ecr-credential-helper

# Or download binary
wget https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/0.7.1/linux-amd64/docker-credential-ecr-login
chmod +x docker-credential-ecr-login
sudo mv docker-credential-ecr-login /usr/local/bin/

# Configure Docker to use ECR helper
mkdir -p ~/.docker
cat > ~/.docker/config.json <<EOF
{
  "credHelpers": {
    "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com": "ecr-login"
  }
}
EOF
```

---

## Part 6: Update Jenkinsfile for ECR

Replace your current Jenkinsfile with this ECR-optimized version:

```groovy
pipeline {
    agent any
    
    environment {
        // Application
        APP_NAME = 'springboot-app'
        APP_VERSION = "${env.BUILD_NUMBER}"
        
        // AWS Configuration
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
        
        // ECR Configuration
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPOSITORY = "${APP_NAME}"
        IMAGE_URI = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
        IMAGE_TAG = "${APP_VERSION}"
        
        // EKS Configuration
        EKS_CLUSTER_NAME = 'my-eks-cluster'
        K8S_NAMESPACE = 'production'
        
        // S3 Configuration
        S3_BUCKET = 'my-artifacts-bucket-20260427170349'
    }
    
    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                    jacoco execPattern: '**/target/jacoco.exec'
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                            -Dsonar.projectKey=${APP_NAME} \
                            -Dsonar.projectName=${APP_NAME} \
                            -Dsonar.login=\${SONAR_TOKEN}
                        """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }
        
        stage('Publish to Nexus') {
            steps {
                script {
                    sh """
                        mvn deploy -DskipTests \
                        -DaltDeploymentRepository=nexus::default::http://nexus:8081/repository/maven-releases/
                    """
                }
            }
        }
        
        stage('ECR Login') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    """
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t ${IMAGE_URI}:${IMAGE_TAG} .
                        docker tag ${IMAGE_URI}:${IMAGE_TAG} ${IMAGE_URI}:latest
                        docker tag ${IMAGE_URI}:${IMAGE_TAG} ${IMAGE_URI}:${GIT_COMMIT_SHORT}
                    """
                }
            }
        }
        
        stage('Trivy Security Scan') {
            steps {
                script {
                    sh """
                        trivy image --severity HIGH,CRITICAL \
                        --format json \
                        --output trivy-report.json \
                        ${IMAGE_URI}:${IMAGE_TAG}
                        
                        trivy image --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${IMAGE_URI}:${IMAGE_TAG}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        docker push ${IMAGE_URI}:${IMAGE_TAG}
                        docker push ${IMAGE_URI}:latest
                        docker push ${IMAGE_URI}:${GIT_COMMIT_SHORT}
                    """
                }
            }
        }
        
        stage('ECR Image Scan') {
            steps {
                script {
                    sh """
                        aws ecr start-image-scan \
                        --repository-name ${ECR_REPOSITORY} \
                        --image-id imageTag=${IMAGE_TAG} \
                        --region ${AWS_REGION}
                        
                        echo "Waiting for scan to complete..."
                        sleep 30
                        
                        aws ecr describe-image-scan-findings \
                        --repository-name ${ECR_REPOSITORY} \
                        --image-id imageTag=${IMAGE_TAG} \
                        --region ${AWS_REGION}
                    """
                }
            }
        }
        
        stage('Backup to S3') {
            steps {
                script {
                    sh """
                        aws s3 cp target/*.jar s3://${S3_BUCKET}/artifacts/${APP_NAME}/${APP_VERSION}/ \
                        --region ${AWS_REGION}
                        
                        aws s3 cp trivy-report.json s3://${S3_BUCKET}/security-reports/${APP_NAME}/${APP_VERSION}/ \
                        --region ${AWS_REGION}
                    """
                }
            }
        }
        
        stage('Update K8s Manifests') {
            steps {
                script {
                    sh """
                        sed -i 's|IMAGE_URI|${IMAGE_URI}|g' k8s/deployment.yaml
                        sed -i 's|IMAGE_TAG|${IMAGE_TAG}|g' k8s/deployment.yaml
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh """
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/configmap.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/secret.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/serviceaccount.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
                        
                        kubectl rollout status deployment/${APP_NAME} -n ${K8S_NAMESPACE} --timeout=5m
                    """
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    sh """
                        kubectl wait --for=condition=ready pod \
                        -l app=${APP_NAME} \
                        -n ${K8S_NAMESPACE} \
                        --timeout=300s
                        
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=${APP_NAME}
                    """
                }
            }
        }
        
        stage('Tag Release') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh """
                        # Tag image as release
                        docker tag ${IMAGE_URI}:${IMAGE_TAG} ${IMAGE_URI}:release-${IMAGE_TAG}
                        docker push ${IMAGE_URI}:release-${IMAGE_TAG}
                        
                        # Add lifecycle tag
                        aws ecr put-image-tag-mutability \
                        --repository-name ${ECR_REPOSITORY} \
                        --image-tag-mutability IMMUTABLE \
                        --region ${AWS_REGION}
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Clean up Docker images
            sh """
                docker rmi ${IMAGE_URI}:${IMAGE_TAG} || true
                docker rmi ${IMAGE_URI}:latest || true
                docker rmi ${IMAGE_URI}:${GIT_COMMIT_SHORT} || true
            """
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully!"
            echo "Image pushed to ECR: ${IMAGE_URI}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
```

---

## Part 7: Update deployment.yaml for ECR

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: springboot-app
  template:
    metadata:
      labels:
        app: springboot-app
    spec:
      serviceAccountName: springboot-app-sa
      containers:
      - name: springboot-app
        image: IMAGE_URI:IMAGE_TAG  # Will be replaced by Jenkins
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          valueFrom:
            configMapKeyRef:
              name: springboot-app-config
              key: SPRING_PROFILES_ACTIVE
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      # No imagePullSecrets needed - EKS nodes have ECR access by default
```

---

## Part 8: Configure EKS Nodes for ECR Access

EKS nodes need permission to pull from ECR:

```bash
# Get EKS node role
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --nodegroup-name <your-nodegroup-name> \
  --query "nodegroup.nodeRole" \
  --output text | cut -d'/' -f2)

# Attach ECR read policy
aws iam attach-role-policy \
  --role-name ${NODE_ROLE} \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

---

## Part 9: ECR Lifecycle Policy (Clean Up Old Images)

```bash
# Create lifecycle policy
cat > lifecycle-policy.json <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Remove untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

# Apply lifecycle policy
aws ecr put-lifecycle-policy \
  --repository-name ${REPO_NAME} \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region ${AWS_REGION}
```

---

## Part 10: Test ECR Integration

### Test ECR Login

```bash
# On Jenkins server
sudo su - jenkins

# Test ECR login
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Should see: Login Succeeded
```

### Test Image Push

```bash
# Build test image
docker build -t test:1.0 .

# Tag for ECR
docker tag test:1.0 ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test

# Push to ECR
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test

# Verify in ECR
aws ecr list-images --repository-name springboot-app --region us-east-1
```

---

## Part 11: Monitoring and Best Practices

### Enable CloudWatch Logs for ECR

```bash
# Enable logging
aws ecr put-registry-policy \
  --policy-text file://registry-policy.json \
  --region ${AWS_REGION}
```

### Set Up Alarms

```bash
# Create CloudWatch alarm for failed pushes
aws cloudwatch put-metric-alarm \
  --alarm-name ecr-push-failures \
  --alarm-description "Alert on ECR push failures" \
  --metric-name RepositoryPushCount \
  --namespace AWS/ECR \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator LessThanThreshold
```

### Best Practices

1. ✅ **Use IAM Roles** instead of access keys
2. ✅ **Enable image scanning** on push
3. ✅ **Implement lifecycle policies** to clean old images
4. ✅ **Tag images** with multiple tags (version, git commit, latest)
5. ✅ **Use immutable tags** for production releases
6. ✅ **Enable encryption** at rest
7. ✅ **Monitor costs** - ECR charges for storage
8. ✅ **Use cross-region replication** for DR
9. ✅ **Implement least privilege** IAM policies
10. ✅ **Regular security scans** with Trivy + ECR scanning

---

## Summary

Your Jenkins pipeline now:
1. ✅ Authenticates to ECR using IAM role
2. ✅ Builds Docker images
3. ✅ Scans with Trivy
4. ✅ Pushes to ECR (not Docker Hub)
5. ✅ Triggers ECR image scanning
6. ✅ Deploys to EKS from ECR
7. ✅ No Docker Hub rate limits
8. ✅ Better security with IAM
9. ✅ Automatic cleanup with lifecycle policies
10. ✅ Built-in vulnerability scanning

**All configured with AWS best practices!**
