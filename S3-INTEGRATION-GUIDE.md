# S3 Integration Guide

## What Was Added

Your Spring Boot application now has full S3 integration with the following features:

### New Files Created

1. **AwsConfig.java** - AWS S3 client configuration
2. **S3Service.java** - S3 operations service
3. **S3Controller.java** - REST API endpoints for S3

### Updated Files

1. **pom.xml** - Added AWS SDK dependency
2. **application.yml** - Added AWS configuration
3. **HealthController.java** - Added S3 status to health check

---

## API Endpoints

### 1. Check S3 Health
```bash
GET /api/s3/health
```

**Response:**
```json
{
  "bucket": "my-artifacts-bucket-20260427170349",
  "accessible": true,
  "status": "UP"
}
```

### 2. Upload File to S3
```bash
POST /api/s3/upload
Content-Type: application/json

{
  "key": "test.txt",
  "content": "Hello from Spring Boot!"
}
```

**Response:**
```json
{
  "message": "Successfully uploaded: test.txt",
  "key": "test.txt",
  "bucket": "my-artifacts-bucket-20260427170349"
}
```

### 3. Download File from S3
```bash
GET /api/s3/download/test.txt
```

**Response:**
```json
{
  "key": "test.txt",
  "content": "Hello from Spring Boot!",
  "bucket": "my-artifacts-bucket-20260427170349"
}
```

### 4. List All Files
```bash
GET /api/s3/list
```

**Response:**
```json
{
  "bucket": "my-artifacts-bucket-20260427170349",
  "count": 5,
  "files": [
    "test.txt",
    "data/file1.json",
    "logs/app.log"
  ]
}
```

### 5. Delete File
```bash
DELETE /api/s3/delete/test.txt
```

**Response:**
```json
{
  "message": "Successfully deleted: test.txt",
  "key": "test.txt",
  "bucket": "my-artifacts-bucket-20260427170349"
}
```

### 6. Enhanced Health Check
```bash
GET /
```

**Response:**
```json
{
  "status": "UP",
  "message": "Spring Boot Application is running!",
  "version": "1.0.0",
  "s3_enabled": true,
  "s3_bucket": "my-artifacts-bucket-20260427170349",
  "s3_accessible": true
}
```

---

## Testing Locally

### 1. Build the Application
```powershell
mvn clean package
```

### 2. Run with AWS Credentials
```powershell
# Set environment variables
$env:AWS_S3_BUCKET="my-artifacts-bucket-20260427170349"
$env:AWS_REGION="us-east-1"
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"

# Run the application
mvn spring-boot:run
```

### 3. Test the Endpoints

**Check S3 Health:**
```powershell
curl http://localhost:8080/api/s3/health
```

**Upload a File:**
```powershell
$body = @{
    key = "test.txt"
    content = "Hello from Spring Boot!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/api/s3/upload" `
  -Method POST `
  -Body $body `
  -ContentType "application/json"
```

**List Files:**
```powershell
curl http://localhost:8080/api/s3/list
```

**Download File:**
```powershell
curl http://localhost:8080/api/s3/download/test.txt
```

**Delete File:**
```powershell
Invoke-RestMethod -Uri "http://localhost:8080/api/s3/delete/test.txt" -Method DELETE
```

---

## Testing in Kubernetes

### 1. Build and Push Docker Image
```powershell
# Build image
docker build -t your-dockerhub-username/springboot-app:1.0.0 .

# Push to registry
docker push your-dockerhub-username/springboot-app:1.0.0
```

### 2. Deploy to EKS
```powershell
# Apply all Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check deployment
kubectl get pods -n production
kubectl logs -n production -l app=springboot-app
```

### 3. Test from Pod
```powershell
# Port forward to access the app
kubectl port-forward -n production svc/springboot-service 8080:8080

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/api/s3/health
```

---

## How IAM Role Works in EKS

### Without Credentials in Code

Your application automatically gets AWS credentials through:

1. **Service Account** with IAM role annotation
2. **IRSA (IAM Roles for Service Accounts)** - EKS injects credentials
3. **DefaultCredentialsProvider** in code picks them up automatically

**No need to:**
- ❌ Store AWS credentials in code
- ❌ Store credentials in ConfigMap/Secret
- ❌ Manually configure credentials

**The IAM role provides:**
- ✅ Automatic credential rotation
- ✅ Temporary credentials
- ✅ Least privilege access
- ✅ Audit trail in CloudTrail

---

## Configuration

### Environment Variables (from ConfigMap)

```yaml
AWS_S3_BUCKET: "my-artifacts-bucket-20260427170349"
AWS_REGION: "us-east-1"
```

### Application Properties

```yaml
aws:
  s3:
    bucket: ${AWS_S3_BUCKET:my-artifacts-bucket-20260427170349}
  region: ${AWS_REGION:us-east-1}
```

### IAM Policy (Already Created)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-artifacts-bucket-20260427170349",
        "arn:aws:s3:::my-artifacts-bucket-20260427170349/*"
      ]
    }
  ]
}
```

---

## Troubleshooting

### Issue: "Access Denied" Error

**Check:**
1. IAM role is attached to service account
2. Service account is used in deployment
3. IAM policy has correct permissions

```powershell
# Verify service account
kubectl describe serviceaccount springboot-app-sa -n production

# Check pod is using service account
kubectl get pod -n production -o yaml | Select-String "serviceAccount"

# Check IAM role
aws iam get-role --role-name <role-name>
```

### Issue: "Bucket Not Found"

**Check:**
1. Bucket name is correct in ConfigMap
2. Bucket exists in the same region

```powershell
# List buckets
aws s3 ls

# Check bucket region
aws s3api get-bucket-location --bucket my-artifacts-bucket-20260427170349
```

### Issue: Application Can't Connect to S3

**Check logs:**
```powershell
kubectl logs -n production -l app=springboot-app --tail=100
```

**Common causes:**
- Network policy blocking egress
- IAM role not properly configured
- Wrong region specified

---

## Use Cases

### 1. Store Application Logs
```java
s3Service.uploadText("logs/app-" + LocalDate.now() + ".log", logContent);
```

### 2. Store User Uploads
```java
s3Service.uploadText("uploads/" + userId + "/" + filename, fileContent);
```

### 3. Configuration Backup
```java
s3Service.uploadText("backups/config-" + timestamp + ".json", configJson);
```

### 4. Data Export
```java
String csvData = generateReport();
s3Service.uploadText("reports/monthly-" + month + ".csv", csvData);
```

---

## Security Best Practices

✅ **Use IAM roles** - No hardcoded credentials
✅ **Least privilege** - Only grant necessary S3 permissions
✅ **Bucket policies** - Restrict access at bucket level
✅ **Encryption** - Enable S3 encryption at rest
✅ **Versioning** - Enable bucket versioning for data protection
✅ **Logging** - Enable S3 access logging
✅ **VPC Endpoints** - Use VPC endpoints for private access

---

## Next Steps

1. ✅ S3 integration is complete
2. Build and test locally
3. Build Docker image
4. Deploy to EKS
5. Test S3 endpoints in production
6. Set up Jenkins pipeline to automate deployment

---

## Summary

Your Spring Boot application now has:
- ✅ Full S3 integration
- ✅ REST API for S3 operations
- ✅ Automatic AWS authentication via IAM roles
- ✅ Health checks for S3 connectivity
- ✅ Production-ready error handling
- ✅ Comprehensive logging

**No AWS credentials needed in code - everything is handled by IAM roles!**
