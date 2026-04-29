# Jenkins IAM Role Setup via AWS Console

Step-by-step guide to create and attach IAM role to Jenkins EC2 instance using AWS Console.

---

## Overview

Jenkins server needs an IAM role with permissions to:
- Push/pull images to/from ECR
- Deploy to EKS cluster
- Upload artifacts to S3
- Scan images in ECR

---

## Part 1: Create IAM Policy for ECR Access

### Step 1: Go to IAM Policies

1. Open AWS Console: https://console.aws.amazon.com
2. Search for **IAM** in the search bar
3. Click **IAM** service
4. In the left sidebar, click **Policies**
5. Click **Create policy** button

### Step 2: Create ECR Policy

1. Click on the **JSON** tab
2. Delete the default JSON
3. Copy and paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRRepositoryAccess",
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
        "ecr:DescribeImages",
        "ecr:StartImageScan",
        "ecr:DescribeImageScanFindings"
      ],
      "Resource": "arn:aws:ecr:us-east-1:*:repository/springboot-app"
    }
  ]
}
```

4. Click **Next: Tags** (optional, skip tags)
5. Click **Next: Review**
6. **Policy name:** `JenkinsECRPolicy`
7. **Description:** `Allows Jenkins to push/pull images to ECR and scan images`
8. Click **Create policy**

✅ **Policy created!**

---

## Part 2: Create IAM Policy for EKS Access

### Step 1: Create EKS Policy

1. Go to **IAM** → **Policies**
2. Click **Create policy**
3. Click **JSON** tab
4. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSClusterAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAuth",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

5. Click **Next: Tags** (skip)
6. Click **Next: Review**
7. **Policy name:** `JenkinsEKSPolicy`
8. **Description:** `Allows Jenkins to access EKS cluster for deployments`
9. Click **Create policy**

✅ **Policy created!**

---

## Part 3: Create IAM Policy for S3 Access

### Step 1: Create S3 Policy

1. Go to **IAM** → **Policies**
2. Click **Create policy**
3. Click **JSON** tab
4. Paste this policy (replace with your bucket name):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ArtifactsBucket",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-artifacts-bucket-20260427170349",
        "arn:aws:s3:::my-artifacts-bucket-20260427170349/*"
      ]
    }
  ]
}
```

5. Click **Next: Tags** (skip)
6. Click **Next: Review**
7. **Policy name:** `JenkinsS3Policy`
8. **Description:** `Allows Jenkins to upload artifacts to S3 bucket`
9. Click **Create policy**

✅ **Policy created!**

---

## Part 4: Create IAM Role for Jenkins

### Step 1: Create Role

1. Go to **IAM** → **Roles**
2. Click **Create role** button

### Step 2: Select Trusted Entity

1. **Trusted entity type:** Select **AWS service**
2. **Use case:** Select **EC2**
3. Click **Next**

### Step 3: Attach Policies

Search and select these policies (use the search box):

**Custom Policies (created above):**
- ☑️ `JenkinsECRPolicy`
- ☑️ `JenkinsEKSPolicy`
- ☑️ `JenkinsS3Policy`

**AWS Managed Policies:**
- ☑️ `AmazonEC2ContainerRegistryReadOnly` (for pulling images)

**Optional (if Jenkins needs to manage EC2):**
- ☑️ `AmazonEC2ReadOnlyAccess` (to describe instances)

Click **Next**

### Step 4: Name and Create Role

1. **Role name:** `JenkinsServerRole`
2. **Description:** `IAM role for Jenkins server with ECR, EKS, and S3 access`
3. **Review** the selected policies
4. Click **Create role**

✅ **Role created!**

---

## Part 5: Attach Role to Jenkins EC2 Instance

### Step 1: Find Jenkins Instance

1. Go to **EC2** service (search for EC2 in AWS Console)
2. Click **Instances** in the left sidebar
3. Find your Jenkins server instance
   - Look for instance with tag `Name: Jenkins-Server`
   - Or identify by IP address
4. Select the instance (checkbox)

### Step 2: Attach IAM Role

1. Click **Actions** dropdown (top right)
2. Go to **Security** → **Modify IAM role**
3. In the **IAM role** dropdown, select **JenkinsServerRole**
4. Click **Update IAM role**

✅ **Role attached to Jenkins instance!**

### Step 3: Verify Role Attachment

1. Select your Jenkins instance
2. Click on **Details** tab (bottom panel)
3. Look for **IAM Role:** should show `JenkinsServerRole`

---

## Part 6: Verify IAM Role on Jenkins Server

### Step 1: SSH to Jenkins Server

```bash
ssh -i your-key.pem ubuntu@<jenkins-server-public-ip>
```

### Step 2: Test IAM Role

```bash
# Test AWS CLI access
aws sts get-caller-identity

# Should show:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX:i-xxxxxxxxxxxxxxxxx",
#     "Account": "123456789012",
#     "Arn": "arn:aws:sts::123456789012:assumed-role/JenkinsServerRole/i-xxxxxxxxxxxxxxxxx"
# }

# Test ECR access
aws ecr describe-repositories --region us-east-1

# Test EKS access
aws eks list-clusters --region us-east-1

# Test S3 access
aws s3 ls s3://my-artifacts-bucket-20260427170349/
```

✅ **If all commands work, IAM role is configured correctly!**

---

## Part 7: Configure EKS Node Role for ECR Access

Your EKS worker nodes also need permission to pull images from ECR.

### Step 1: Find EKS Node Role

1. Go to **EKS** service
2. Click on your cluster: **my-eks-cluster**
3. Click **Compute** tab
4. Click on your **Node group** name
5. Scroll down to **Node IAM role ARN**
6. Copy the role name (e.g., `eksctl-my-eks-cluster-nodegroup-NodeInstanceRole-XXXXX`)

### Step 2: Attach ECR Policy to Node Role

1. Go to **IAM** → **Roles**
2. Search for the node role name (from step 1)
3. Click on the role
4. Click **Attach policies** button
5. Search for: `AmazonEC2ContainerRegistryReadOnly`
6. Select the checkbox
7. Click **Attach policy**

✅ **EKS nodes can now pull from ECR!**

---

## Part 8: Create ECR Repository

### Step 1: Go to ECR

1. Search for **ECR** in AWS Console
2. Click **Elastic Container Registry**
3. Make sure you're in **us-east-1** region (top right)

### Step 2: Create Repository

1. Click **Get Started** or **Create repository**
2. **Visibility settings:** Select **Private**
3. **Repository name:** `springboot-app`
4. **Tag immutability:** Leave as **Disabled** (or enable for production)
5. **Image scan settings:** 
   - ☑️ Enable **Scan on push**
6. **Encryption settings:**
   - Select **AES-256** (default)
7. Click **Create repository**

✅ **ECR repository created!**

### Step 3: Copy Repository URI

1. Click on **springboot-app** repository
2. Copy the **URI** (looks like: `123456789012.dkr.ecr.us-east-1.amazonaws.com/springboot-app`)
3. Save this URI - you'll need it for verification

---

## Part 9: Apply ECR Lifecycle Policy

### Step 1: Open Repository

1. Go to **ECR** → **Repositories**
2. Click on **springboot-app**

### Step 2: Create Lifecycle Policy

1. Click **Lifecycle Policy** tab (left sidebar)
2. Click **Create rule**

**Rule 1: Keep last 10 images**
1. **Rule priority:** `1`
2. **Rule description:** `Keep last 10 images`
3. **Image status:** `Any`
4. **Match criteria:** `Image count more than`
5. **Count:** `10`
6. Click **Save**

**Rule 2: Remove untagged images**
1. Click **Create rule** again
2. **Rule priority:** `2`
3. **Rule description:** `Remove untagged images older than 7 days`
4. **Image status:** `Untagged`
5. **Match criteria:** `Since image pushed`
6. **Count:** `7`
7. **Unit:** `days`
8. Click **Save**

✅ **Lifecycle policy applied!**

---

## Part 10: Test ECR Access from Jenkins

### Step 1: SSH to Jenkins Server

```bash
ssh -i your-key.pem ubuntu@<jenkins-server-ip>
```

### Step 2: Switch to Jenkins User

```bash
sudo su - jenkins
```

### Step 3: Test ECR Login

```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Should see: Login Succeeded
```

### Step 4: Test Image Push (Optional)

```bash
# Pull a test image
docker pull hello-world

# Tag for ECR
docker tag hello-world:latest ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test

# Push to ECR
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/springboot-app:test

# Verify in ECR
aws ecr list-images --repository-name springboot-app --region us-east-1
```

✅ **If push succeeds, everything is working!**

---

## Summary of Created Resources

### IAM Policies Created:
1. ✅ `JenkinsECRPolicy` - ECR push/pull/scan permissions
2. ✅ `JenkinsEKSPolicy` - EKS cluster access
3. ✅ `JenkinsS3Policy` - S3 bucket access

### IAM Role Created:
1. ✅ `JenkinsServerRole` - Role with all policies attached

### Role Attachments:
1. ✅ `JenkinsServerRole` attached to Jenkins EC2 instance
2. ✅ `AmazonEC2ContainerRegistryReadOnly` attached to EKS node role

### ECR Resources:
1. ✅ `springboot-app` repository created
2. ✅ Image scanning enabled
3. ✅ Lifecycle policy applied

---

## Verification Checklist

Run these commands on Jenkins server to verify:

```bash
# 1. Check IAM role
aws sts get-caller-identity
# Should show JenkinsServerRole

# 2. Check ECR access
aws ecr describe-repositories --region us-east-1
# Should list springboot-app

# 3. Check EKS access
aws eks describe-cluster --name my-eks-cluster --region us-east-1
# Should show cluster details

# 4. Check S3 access
aws s3 ls s3://my-artifacts-bucket-20260427170349/
# Should list bucket contents (or empty)

# 5. Test ECR login
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
# Should see: Login Succeeded
```

**All checks passed?** ✅ You're ready to run the Jenkins pipeline!

---

## Troubleshooting

### Issue: "aws: command not found"

**Solution:** Install AWS CLI on Jenkins server
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Issue: "Unable to locate credentials"

**Solution:** Check IAM role is attached
1. Go to EC2 → Instances
2. Select Jenkins instance
3. Check **IAM Role** in Details tab
4. Should show `JenkinsServerRole`

### Issue: "AccessDenied" when accessing ECR

**Solution:** Check policy is attached to role
1. Go to IAM → Roles → JenkinsServerRole
2. Click **Permissions** tab
3. Verify `JenkinsECRPolicy` is listed
4. Click on policy and verify JSON is correct

### Issue: "Repository does not exist"

**Solution:** Create ECR repository
1. Go to ECR service
2. Create repository named `springboot-app`
3. Make sure you're in `us-east-1` region

### Issue: EKS pods can't pull images

**Solution:** Check EKS node role
1. Go to EKS → Cluster → Compute → Node group
2. Note the Node IAM role
3. Go to IAM → Roles → [Node role]
4. Verify `AmazonEC2ContainerRegistryReadOnly` is attached

---

## Next Steps

1. ✅ IAM role created and attached
2. ✅ ECR repository created
3. ✅ Permissions verified
4. ➡️ **Next:** Run Jenkins pipeline to test end-to-end
5. ➡️ Commit and push code changes
6. ➡️ Trigger Jenkins build
7. ➡️ Verify image appears in ECR
8. ➡️ Verify deployment to EKS

---

## Quick Reference

**Jenkins IAM Role:** `JenkinsServerRole`

**Policies Attached:**
- `JenkinsECRPolicy` (custom)
- `JenkinsEKSPolicy` (custom)
- `JenkinsS3Policy` (custom)
- `AmazonEC2ContainerRegistryReadOnly` (AWS managed)

**ECR Repository:** `springboot-app`

**ECR URI:** `<account-id>.dkr.ecr.us-east-1.amazonaws.com/springboot-app`

**S3 Bucket:** `my-artifacts-bucket-20260427170349`

**EKS Cluster:** `my-eks-cluster`

**Region:** `us-east-1`

---

**Your Jenkins server now has all the IAM permissions needed for the CI/CD pipeline!** 🚀
