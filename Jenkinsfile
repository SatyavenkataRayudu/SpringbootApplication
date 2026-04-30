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
        jdk 'JDK-21'
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
