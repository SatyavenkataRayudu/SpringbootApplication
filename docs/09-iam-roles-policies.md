# IAM Roles and Policies (AWS Console)

This document explains how to create IAM roles and attach IAM policies using the AWS Management Console. Use these steps when you need IAM access for EKS, Jenkins, S3, or other AWS services.

---

## 1. Create an IAM Role

1. Open the AWS Management Console.
2. Go to the `IAM` service.
3. In the left navigation, choose `Roles`.
4. Click `Create role`.

### 1.1 Choose trusted entity

- For AWS services, select `AWS service`.
- Choose the service that will assume the role (for example `EC2`, `EKS`, or `Lambda`).
- If another AWS account or external identity needs access, choose `Another AWS account` or `Web identity` as appropriate.
- Click `Next`.

### 1.2 Select permissions

- Search for an existing managed policy if one already matches your needs.
- Otherwise, click `Create policy` to build a custom policy.
- After attaching the chosen policy, click `Next`.

### 1.3 Add tags (optional)

- Add tags if your organization requires them.
- Click `Next`.

### 1.4 Review and create

- Enter a role name, such as `EKS-NodeRole`, `Jenkins-ServiceRole`, or `S3-ReadOnlyRole`.
- Review the trusted entity and permissions.
- Click `Create role`.

---

## 2. Attach a Policy to a Role

If you create the role first and need to attach a policy later:

1. In IAM, go to `Roles`.
2. Select the role you created.
3. In the `Permissions` tab, click `Add permissions`.
4. Choose `Attach policies`.
5. Search for the policy by name and select it.
6. Click `Next` and then `Add permissions`.

---

## 3. Create a Custom Policy in the Console

1. In IAM, go to `Policies`.
2. Click `Create policy`.
3. Choose the `JSON` tab or the `Visual editor`.
4. Enter the policy document.
5. Click `Next`, add tags if needed, then click `Next` again.
6. Name the policy and save.

### 3.1 Example: S3 Read-Only Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

### 3.2 Example: EKS Service Role Policy

For EKS control plane or worker node roles, use AWS-managed policies if possible, such as `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, or other recommended AWS policies.

### 3.3 Example: Jenkins Service Role Policy

If Jenkins needs access to AWS resources, attach only the permissions needed for your pipeline.

Example minimal policy for S3 and ECR read access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 4. Notes for this repository

- If you are deploying `EKS` from this project, create the IAM role with the correct trusted entity for EKS and attach the required EKS policies.
- If Jenkins needs AWS access for pipeline deployment, create a separate IAM role for Jenkins and attach only the permissions required by the CI/CD jobs.
- Avoid granting broad permissions such as `AdministratorAccess` unless absolutely necessary.

---

## 5. Verify the role and policy

1. Open the role in IAM.
2. Confirm the policy appears under `Permissions`.
3. Review the `Trust relationships` tab to ensure the correct service or account can assume the role.

---

## 6. Further reading

- AWS IAM documentation: https://docs.aws.amazon.com/iam/
- AWS EKS IAM documentation: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles.html
