# Authentication and Security Integration

## Overview

This guide covers centralized authentication and security best practices for integrating Jenkins, SonarQube, and Nexus.

## Authentication Strategy Options

### Option 1: LDAP/Active Directory (Recommended for Enterprise)
- Centralized user management
- Single source of truth
- Works with existing corporate directory
- Supports group-based access control

### Option 2: OAuth 2.0 / SAML SSO (Modern Approach)
- Single Sign-On experience
- Integration with GitHub, GitLab, Google, Okta
- Better user experience
- Modern security standards

### Option 3: Local Users + API Tokens (Simple/Small Teams)
- No external dependencies
- Quick to set up
- Manual user management
- Good for small teams or development

## 1. LDAP/Active Directory Integration

### Jenkins LDAP Configuration

#### Install LDAP Plugin

1. Manage Jenkins → Manage Plugins → Available
2. Search and install: "LDAP Plugin"
3. Restart Jenkins

#### Configure LDAP

1. Manage Jenkins → Configure Global Security
2. Security Realm: LDAP
3. Configuration:

```
Server: ldap://your-ldap-server:389
Root DN: dc=example,dc=com
User search base: ou=users
User search filter: uid={0}
Group search base: ou=groups
Group search filter: (memberUid={0})
Manager DN: cn=admin,dc=example,dc=com
Manager Password: your-ldap-password
```

4. Test LDAP Settings
5. Authorization: Matrix-based security or Role-Based Strategy

#### Configure Role-Based Access

Install "Role-based Authorization Strategy" plugin:

```
Roles:
- admin: Full access
- developer: Build, read, workspace
- viewer: Read-only access

Map LDAP groups to roles:
- LDAP Group "jenkins-admins" → admin role
- LDAP Group "developers" → developer role
- LDAP Group "team-members" → viewer role
```

### SonarQube LDAP Configuration

#### Configure LDAP in SonarQube

1. Stop SonarQube:
```bash
docker stop sonarqube
```

2. Edit configuration:
```bash
docker exec sonarqube vi /opt/sonarqube/conf/sonar.properties
```

3. Add LDAP configuration:

```properties
# LDAP Configuration
sonar.security.realm=LDAP

# LDAP Server
ldap.url=ldap://your-ldap-server:389

# Bind credentials
ldap.bindDn=cn=admin,dc=example,dc=com
ldap.bindPassword=your-ldap-password

# User Configuration
ldap.user.baseDn=ou=users,dc=example,dc=com
ldap.user.request=(&(objectClass=inetOrgPerson)(uid={login}))
ldap.user.realNameAttribute=cn
ldap.user.emailAttribute=mail

# Group Configuration
ldap.group.baseDn=ou=groups,dc=example,dc=com
ldap.group.request=(&(objectClass=posixGroup)(memberUid={uid}))
ldap.group.idAttribute=cn
```

4. Restart SonarQube:
```bash
docker start sonarqube
```

#### Configure Group Permissions

1. Administration → Security → Groups
2. Create groups matching LDAP groups:
   - `sonar-admins`: Full administration
   - `sonar-developers`: Browse, Execute Analysis
   - `sonar-viewers`: Browse only

3. Administration → Security → Global Permissions
4. Assign permissions to groups

### Nexus LDAP Configuration

#### Configure LDAP

1. Settings (gear icon) → Security → LDAP
2. Create LDAP connection:

```
Name: Company LDAP
Protocol: ldap
Hostname: your-ldap-server
Port: 389
Search base: dc=example,dc=com

Authentication:
- Method: Simple Authentication
- Username: cn=admin,dc=example,dc=com
- Password: your-ldap-password

User Configuration:
- Base DN: ou=users
- Object class: inetOrgPerson
- User ID attribute: uid
- Real name attribute: cn
- Email attribute: mail
- Password attribute: userPassword

Group Configuration:
- Base DN: ou=groups
- Object class: posixGroup
- Group ID attribute: cn
- Group member attribute: memberUid
- Group member format: ${username}
```

3. Verify connection
4. Save

#### Map LDAP Groups to Nexus Roles

1. Settings → Security → Roles
2. Create roles:
   - `nx-ldap-admin`: Full access
   - `nx-ldap-developer`: Deploy artifacts
   - `nx-ldap-viewer`: Read-only

3. Map external groups:
   - LDAP Group `nexus-admins` → `nx-ldap-admin`
   - LDAP Group `developers` → `nx-ldap-developer`
   - LDAP Group `team-members` → `nx-ldap-viewer`

## 2. OAuth 2.0 / GitHub Integration

### Jenkins GitHub OAuth

#### Install GitHub Authentication Plugin

1. Manage Jenkins → Manage Plugins
2. Install: "GitHub Authentication Plugin"

#### Configure GitHub OAuth App

1. GitHub → Settings → Developer settings → OAuth Apps
2. New OAuth App:
   - Application name: Jenkins CI
   - Homepage URL: `http://your-jenkins-url:8080`
   - Authorization callback URL: `http://your-jenkins-url:8080/securityRealm/finishLogin`
3. Save Client ID and Client Secret

#### Configure Jenkins

1. Manage Jenkins → Configure Global Security
2. Security Realm: GitHub Authentication Plugin
3. Configuration:
   - GitHub Web URI: `https://github.com`
   - GitHub API URI: `https://api.github.com`
   - Client ID: Your GitHub OAuth Client ID
   - Client Secret: Your GitHub OAuth Client Secret
   - OAuth Scope: `read:org,user:email`

4. Authorization: GitHub Committer Authorization Strategy
   - Admin User Names: your-github-username
   - Organization Names: your-github-org
   - Use GitHub repository permissions: Yes

### SonarQube GitHub OAuth

#### Install GitHub Authentication Plugin

1. Administration → Marketplace
2. Search: "GitHub Authentication"
3. Install and restart

#### Configure GitHub OAuth App

1. GitHub → Settings → Developer settings → OAuth Apps
2. New OAuth App:
   - Application name: SonarQube
   - Homepage URL: `http://your-sonarqube-url:9000`
   - Authorization callback URL: `http://your-sonarqube-url:9000/oauth2/callback/github`
3. Save Client ID and Client Secret

#### Configure SonarQube

1. Administration → Configuration → General Settings → GitHub
2. Configuration:
   - Enabled: Yes
   - Client ID: Your GitHub OAuth Client ID
   - Client Secret: Your GitHub OAuth Client Secret
   - Organizations: your-github-org (optional)
   - Allow users to sign up: Yes/No

3. Administration → Security → Groups
4. Create group: `github-users`
5. Assign default permissions

### Nexus OAuth (via SAML)

Nexus Repository Manager Pro supports SAML SSO. For OSS version, use LDAP or local users.

## 3. API Token Management (Best Practice)

### Jenkins API Tokens

#### For Users

1. User → Configure
2. API Token → Add new Token
3. Name: `pipeline-token`
4. Generate and save securely

#### For Service Accounts

```bash
# Create service account user
# User: jenkins-service
# Generate API token for automation
```

### SonarQube Tokens

#### User Tokens

1. My Account → Security → Generate Tokens
2. Token types:
   - User Token: Personal analysis
   - Project Analysis Token: Specific project
   - Global Analysis Token: All projects

#### Service Account Tokens

```bash
# Create technical user: jenkins-scanner
# Generate Global Analysis Token
# Use in Jenkins pipeline
```

### Nexus API Tokens (NuGet API Key)

1. User → Profile
2. NuGet API Key → Access API Key
3. Use for programmatic access

## 4. Security Best Practices

### Password Policies

#### Jenkins

1. Manage Jenkins → Configure Global Security
2. Enable: "Password Policy"
3. Configure:
   - Minimum length: 12 characters
   - Require uppercase, lowercase, numbers, special chars
   - Password expiration: 90 days

#### SonarQube

```properties
# sonar.properties
sonar.security.password.minLength=12
sonar.security.password.requireUppercase=true
sonar.security.password.requireLowercase=true
sonar.security.password.requireDigit=true
sonar.security.password.requireSpecialCharacter=true
```

#### Nexus

1. Settings → Security → Anonymous Access
2. Disable anonymous access for write operations
3. Enable for read-only (optional)

### Network Security

#### Use HTTPS/TLS

All tools should use HTTPS in production:

```bash
# Jenkins: Configure reverse proxy (Nginx/Apache)
# SonarQube: Configure HTTPS in sonar.properties
# Nexus: Configure HTTPS in nexus.properties
```

#### Firewall Rules

```bash
# Jenkins
- Allow: 8080 (HTTPS only in production)
- Allow: 50000 (agent communication)

# SonarQube
- Allow: 9000 (HTTPS only in production)

# Nexus
- Allow: 8081 (HTTPS only in production)
- Allow: 8082 (Docker registry, HTTPS only)

# All tools
- Allow: 22 (SSH, restricted IPs only)
- Deny: All other inbound traffic
```

### Secrets Management

#### Jenkins Credentials

Use Jenkins Credentials Plugin:
- Never hardcode secrets in Jenkinsfile
- Use credential IDs
- Rotate credentials regularly

```groovy
// Good
withCredentials([string(credentialsId: 'api-token', variable: 'TOKEN')]) {
    sh "curl -H 'Authorization: Bearer ${TOKEN}' ..."
}

// Bad
sh "curl -H 'Authorization: Bearer abc123' ..."
```

#### AWS Secrets Manager Integration

```groovy
// Install AWS Secrets Manager Credentials Provider Plugin
// Use AWS Secrets Manager for sensitive data
withAWSSecretsManager(credentialsId: 'aws-credentials', region: 'us-east-1') {
    // Secrets automatically available
}
```

### Audit Logging

#### Jenkins

1. Install "Audit Trail Plugin"
2. Manage Jenkins → Configure System → Audit Trail
3. Log to file: `/var/log/jenkins/audit.log`
4. Log pattern: Include user, timestamp, action

#### SonarQube

1. Administration → Configuration → General Settings → Security
2. Enable audit logs
3. Logs location: `/opt/sonarqube/logs/audit.log`

#### Nexus

1. Settings → System → Logging
2. Enable audit logging
3. Review: Settings → System → Support → Audit

### Regular Security Updates

```bash
# Jenkins
# Check for updates: Manage Jenkins → Manage Plugins → Updates
# Enable automatic security updates

# SonarQube
docker pull sonarqube:lts-community
docker stop sonarqube
docker rm sonarqube
# Run with new image

# Nexus
docker pull sonatype/nexus3:latest
docker stop nexus
docker rm nexus
# Run with new image
```

## 5. Integration Testing

### Test LDAP Authentication

```bash
# Jenkins
curl -u ldap-user:password http://jenkins-url:8080/api/json

# SonarQube
curl -u ldap-user:password http://sonarqube-url:9000/api/authentication/validate

# Nexus
curl -u ldap-user:password http://nexus-url:8081/service/rest/v1/status
```

### Test API Tokens

```bash
# Jenkins
curl -u username:api-token http://jenkins-url:8080/api/json

# SonarQube
curl -H "Authorization: Bearer sonar-token" \
  http://sonarqube-url:9000/api/projects/search

# Nexus
curl -u username:password http://nexus-url:8081/service/rest/v1/repositories
```

## 6. Backup Authentication Configuration

### Jenkins

```bash
# Backup config.xml and credentials
sudo tar czf jenkins-auth-backup.tar.gz \
  /var/lib/jenkins/config.xml \
  /var/lib/jenkins/credentials.xml \
  /var/lib/jenkins/secrets/
```

### SonarQube

```bash
# Backup database (includes users and permissions)
docker exec sonarqube-db pg_dump -U sonar sonarqube > sonar-auth-backup.sql
```

### Nexus

```bash
# Backup security configuration
docker exec nexus tar czf /tmp/nexus-security.tar.gz \
  /nexus-data/etc/security \
  /nexus-data/db/security

docker cp nexus:/tmp/nexus-security.tar.gz ./
```

## Summary

### Recommended Setup by Environment

**Development:**
- Local users + API tokens
- Simple and fast
- No external dependencies

**Staging/Production:**
- LDAP/Active Directory (if available)
- OAuth 2.0 for modern teams
- Centralized user management
- Group-based access control

**Security Checklist:**
- ✓ HTTPS/TLS enabled
- ✓ Strong password policies
- ✓ API tokens for automation
- ✓ Regular credential rotation
- ✓ Audit logging enabled
- ✓ Firewall rules configured
- ✓ Regular security updates
- ✓ Backup authentication config

## Next Steps

Return to [Pipeline Deployment](06-pipeline-deployment.md) to complete the setup.
