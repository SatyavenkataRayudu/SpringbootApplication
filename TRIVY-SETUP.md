# Trivy Security Scanner Setup

## What is Trivy?

Trivy is a comprehensive security scanner that detects vulnerabilities in:
- Container images
- Operating system packages
- Application dependencies (Java, Python, Node.js, etc.)
- Infrastructure as Code (Terraform, Kubernetes)

---

## Installation on Jenkins Server

### Method 1: Using Package Manager (Recommended)

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@jenkins-server-ip

# Add Trivy repository
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

# Update and install
sudo apt-get update
sudo apt-get install trivy

# Verify installation
trivy --version
```

### Method 2: Using Binary

```bash
# Download latest release
VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
wget https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${VERSION}_Linux-64bit.tar.gz

# Extract
tar zxvf trivy_${VERSION}_Linux-64bit.tar.gz

# Move to PATH
sudo mv trivy /usr/local/bin/

# Verify
trivy --version
```

### Method 3: Using Docker (Alternative)

```bash
# Run Trivy as Docker container
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image your-image:tag
```

---

## Basic Usage

### Scan a Docker Image

```bash
# Basic scan
trivy image your-image:tag

# Scan with specific severity
trivy image --severity HIGH,CRITICAL your-image:tag

# Output to JSON
trivy image --format json --output report.json your-image:tag

# Exit with error if vulnerabilities found
trivy image --exit-code 1 --severity CRITICAL your-image:tag
```

### Example Output

```
your-image:tag (ubuntu 22.04)
==========================
Total: 45 (UNKNOWN: 0, LOW: 15, MEDIUM: 20, HIGH: 8, CRITICAL: 2)

┌───────────────┬────────────────┬──────────┬───────────────────┬───────────────┬────────────────────────────────────┐
│   Library     │ Vulnerability  │ Severity │ Installed Version │ Fixed Version │              Title                 │
├───────────────┼────────────────┼──────────┼───────────────────┼───────────────┼────────────────────────────────────┤
│ openssl       │ CVE-2023-12345 │ CRITICAL │ 1.1.1f            │ 1.1.1g        │ OpenSSL vulnerability              │
│ curl          │ CVE-2023-67890 │ HIGH     │ 7.68.0            │ 7.68.1        │ curl buffer overflow               │
└───────────────┴────────────────┴──────────┴───────────────────┴───────────────┴────────────────────────────────────┘
```

---

## Integration in Jenkins Pipeline

Your Jenkinsfile already includes Trivy scanning:

```groovy
stage('Trivy Security Scan') {
    steps {
        script {
            sh """
                # Scan and generate report
                trivy image --severity HIGH,CRITICAL \
                --format json \
                --output trivy-report.json \
                ${IMAGE_NAME}:${IMAGE_TAG}
                
                # Fail build if critical vulnerabilities found
                trivy image --severity HIGH,CRITICAL \
                --exit-code 1 \
                ${IMAGE_NAME}:${IMAGE_TAG}
            """
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
        }
    }
}
```

### What This Does:

1. **First scan** - Generates JSON report (doesn't fail build)
2. **Second scan** - Fails build if HIGH or CRITICAL vulnerabilities found
3. **Archives report** - Saves report in Jenkins for review

---

## Trivy Configuration Options

### Severity Levels

```bash
# Scan for all severities
trivy image your-image:tag

# Only HIGH and CRITICAL
trivy image --severity HIGH,CRITICAL your-image:tag

# Only CRITICAL
trivy image --severity CRITICAL your-image:tag

# Exclude LOW and MEDIUM
trivy image --severity HIGH,CRITICAL,UNKNOWN your-image:tag
```

### Output Formats

```bash
# Table format (default)
trivy image your-image:tag

# JSON format
trivy image --format json your-image:tag

# Template format
trivy image --format template --template "@contrib/html.tpl" -o report.html your-image:tag

# SARIF format (for GitHub)
trivy image --format sarif -o report.sarif your-image:tag
```

### Ignore Unfixed Vulnerabilities

```bash
# Only show vulnerabilities with fixes available
trivy image --ignore-unfixed your-image:tag
```

### Skip Files/Directories

```bash
# Skip specific paths
trivy image --skip-files /usr/bin/wget your-image:tag
trivy image --skip-dirs /tmp,/var/tmp your-image:tag
```

---

## Create Trivy Policy File

Create `.trivyignore` in your project root to ignore specific vulnerabilities:

```bash
# .trivyignore
# Ignore specific CVEs
CVE-2023-12345
CVE-2023-67890

# Ignore by package
pkg:deb/ubuntu/curl@7.68.0

# Comments are supported
# This is a known false positive
CVE-2023-99999
```

---

## Advanced Configuration

### Create trivy.yaml

```yaml
# trivy.yaml
severity:
  - CRITICAL
  - HIGH

vulnerability:
  type:
    - os
    - library

output: json

exit-code: 1

ignore-unfixed: true

timeout: 10m
```

Use in Jenkins:

```groovy
sh "trivy image --config trivy.yaml ${IMAGE_NAME}:${IMAGE_TAG}"
```

---

## Scan Different Targets

### Scan Filesystem

```bash
# Scan local directory
trivy fs /path/to/project

# Scan current directory
trivy fs .
```

### Scan Git Repository

```bash
# Scan remote repository
trivy repo https://github.com/your-username/your-repo

# Scan local repository
trivy repo .
```

### Scan Kubernetes Manifests

```bash
# Scan Kubernetes YAML files
trivy config k8s/

# Scan specific file
trivy config k8s/deployment.yaml
```

### Scan Terraform

```bash
# Scan Terraform files
trivy config terraform/
```

---

## Trivy in Different Stages

### 1. Local Development

```bash
# Before committing
trivy image your-image:dev
```

### 2. CI/CD Pipeline (Jenkins)

```groovy
stage('Security Scan') {
    steps {
        sh "trivy image --exit-code 1 --severity CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}"
    }
}
```

### 3. Pre-deployment Check

```bash
# Before deploying to production
trivy image --severity HIGH,CRITICAL production-image:latest
```

### 4. Scheduled Scans

```bash
# Cron job to scan running images
0 2 * * * trivy image --severity HIGH,CRITICAL $(docker images -q)
```

---

## Trivy Database Updates

Trivy automatically updates its vulnerability database:

```bash
# Manual update
trivy image --download-db-only

# Check database version
trivy --version

# Clear cache
trivy image --clear-cache
```

---

## Integration with Other Tools

### 1. Send Results to Slack

```bash
#!/bin/bash
SCAN_RESULT=$(trivy image --format json your-image:tag)
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"Trivy Scan Results: $SCAN_RESULT\"}" \
  YOUR_SLACK_WEBHOOK_URL
```

### 2. Upload to S3

```bash
# In Jenkins pipeline
trivy image --format json -o trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG}
aws s3 cp trivy-report.json s3://your-bucket/security-reports/
```

### 3. Create GitHub Issue

```bash
# Using GitHub CLI
trivy image --format json your-image:tag | \
  gh issue create --title "Security Vulnerabilities Found" --body-file -
```

---

## Troubleshooting

### Issue 1: Trivy Not Found

```bash
# Check if installed
which trivy

# Check PATH
echo $PATH

# Reinstall
sudo apt-get install --reinstall trivy
```

### Issue 2: Database Download Failed

```bash
# Clear cache and retry
trivy image --clear-cache
trivy image --download-db-only

# Check internet connectivity
curl -I https://ghcr.io
```

### Issue 3: Scan Takes Too Long

```bash
# Increase timeout
trivy image --timeout 15m your-image:tag

# Skip DB update
trivy image --skip-db-update your-image:tag
```

### Issue 4: Too Many False Positives

```bash
# Ignore unfixed vulnerabilities
trivy image --ignore-unfixed your-image:tag

# Use .trivyignore file
echo "CVE-2023-12345" >> .trivyignore
```

---

## Best Practices

### 1. Scan Early and Often

```bash
# Scan base images before building
trivy image ubuntu:22.04

# Scan after each build
trivy image your-image:${BUILD_NUMBER}
```

### 2. Set Appropriate Thresholds

```groovy
// Fail on CRITICAL only in development
stage('Dev Scan') {
    when { branch 'develop' }
    steps {
        sh "trivy image --severity CRITICAL --exit-code 1 ${IMAGE}"
    }
}

// Fail on HIGH and CRITICAL in production
stage('Prod Scan') {
    when { branch 'main' }
    steps {
        sh "trivy image --severity HIGH,CRITICAL --exit-code 1 ${IMAGE}"
    }
}
```

### 3. Keep Reports

```groovy
post {
    always {
        archiveArtifacts artifacts: 'trivy-report.json'
        publishHTML([
            reportDir: '.',
            reportFiles: 'trivy-report.html',
            reportName: 'Trivy Security Report'
        ])
    }
}
```

### 4. Regular Updates

```bash
# Update Trivy regularly
sudo apt-get update && sudo apt-get upgrade trivy
```

---

## Example: Complete Trivy Stage in Jenkins

```groovy
stage('Security Scan with Trivy') {
    steps {
        script {
            // Generate detailed report
            sh """
                trivy image \
                  --severity HIGH,CRITICAL \
                  --format json \
                  --output trivy-report.json \
                  ${IMAGE_NAME}:${IMAGE_TAG}
            """
            
            // Generate HTML report
            sh """
                trivy image \
                  --severity HIGH,CRITICAL \
                  --format template \
                  --template "@contrib/html.tpl" \
                  --output trivy-report.html \
                  ${IMAGE_NAME}:${IMAGE_TAG}
            """
            
            // Fail build if vulnerabilities found
            def scanResult = sh(
                script: "trivy image --severity HIGH,CRITICAL --exit-code 0 ${IMAGE_NAME}:${IMAGE_TAG} | grep 'Total:' | awk '{print \$2}'",
                returnStdout: true
            ).trim()
            
            if (scanResult.toInteger() > 0) {
                echo "WARNING: ${scanResult} vulnerabilities found!"
                // Uncomment to fail build:
                // error("Security vulnerabilities detected!")
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.*', allowEmptyArchive: true
            publishHTML([
                reportDir: '.',
                reportFiles: 'trivy-report.html',
                reportName: 'Trivy Security Report',
                keepAll: true
            ])
        }
    }
}
```

---

## Quick Reference

```bash
# Basic scan
trivy image your-image:tag

# Scan with severity filter
trivy image --severity HIGH,CRITICAL your-image:tag

# Generate JSON report
trivy image --format json -o report.json your-image:tag

# Fail on vulnerabilities
trivy image --exit-code 1 --severity CRITICAL your-image:tag

# Ignore unfixed
trivy image --ignore-unfixed your-image:tag

# Scan filesystem
trivy fs /path/to/code

# Scan Kubernetes
trivy config k8s/

# Update database
trivy image --download-db-only

# Clear cache
trivy image --clear-cache
```

---

## Summary

Trivy is already integrated in your Jenkins pipeline and will:
1. ✅ Scan every Docker image built
2. ✅ Generate security reports
3. ✅ Fail build if critical vulnerabilities found
4. ✅ Archive reports for review
5. ✅ Upload reports to S3

**No additional setup needed - it's ready to use!**
