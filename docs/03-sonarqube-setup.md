# SonarQube Setup and Configuration

## Installation Options

Choose your preferred installation method:

1. **Docker Installation (Recommended for Quick Setup)** - See below
2. **Native Installation (Recommended for Production)** - See [Native Installation Guide](03-sonarqube-setup-native.md)

**Docker Pros:** Quick setup, easy management, isolated environment
**Native Pros:** Better performance, easier troubleshooting, production-ready

---

## Docker Installation (Quick Setup)

## Server Requirements

### Recommended Instance Sizing

**Minimum Requirements:**
- Instance Type: `t3.medium` (2 vCPU, 4GB RAM)
- Storage: 20GB SSD minimum
- OS: Ubuntu 22.04 LTS

**Production Recommendations:**
- Instance Type: `t3.medium` to `t3.large`
- Storage: 50GB SSD (grows with analysis history)
- Reason: SonarQube runs Elasticsearch internally, which is memory-intensive

**Why Not Identical Servers:**
- SonarQube requires specific Elasticsearch tuning (`vm.max_map_count`)
- Memory-intensive for code analysis and indexing
- Different resource profile than Jenkins (less CPU, more memory)
- Database backend adds overhead

### Cost Considerations

**Separate Server (Recommended):**
- Dedicated resources for code analysis
- Independent scaling based on project size
- Elasticsearch performance isolation
- Better security and access control

**Combined Setup (Dev/Test Only):**
- Can share t3.large (2 vCPU, 8GB RAM) with other tools
- Requires careful memory allocation
- May impact analysis performance during Jenkins builds
- Not recommended for production

## 1. Install SonarQube using Docker

### Prerequisites
- Docker installed
- At least 4GB RAM
- Elasticsearch requirements met

### System Configuration

```bash
# Increase virtual memory (required for Elasticsearch)
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
```

### Run SonarQube Container

```bash
# Create network
docker network create sonarnet

# Run PostgreSQL for SonarQube
docker run -d \
  --name sonarqube-db \
  --network sonarnet \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  -e POSTGRES_DB=sonarqube \
  -v postgresql_data:/var/lib/postgresql/data \
  postgres:15-alpine

# Run SonarQube
docker run -d \
  --name sonarqube \
  --network sonarnet \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:lts-community

# Check logs
docker logs -f sonarqube
```

## 2. Initial SonarQube Configuration

### Access SonarQube

1. Open browser: `http://your-server-ip:9000`
2. Default credentials:
   - Username: `admin`
   - Password: `admin`
3. Change password when prompted

### Create Authentication Token

1. Click on your profile (top right)
2. My Account → Security
3. Generate Token
   - Name: `jenkins-token`
   - Type: Global Analysis Token
   - Expires: No expiration (or set as needed)
4. Copy the token (save it securely)

### Create Project

1. Click "Create Project" → "Manually"
2. Project key: `springboot-app`
3. Display name: `Spring Boot Application`
4. Click "Set Up"
5. Choose "With Jenkins"
6. Follow the instructions (we'll configure Jenkins integration)

## 3. Configure Quality Gates

### Default Quality Gate

1. Quality Gates → Create
2. Name: `Strict Quality Gate`
3. Add Conditions:
   - Coverage < 80% (Error)
   - Duplicated Lines (%) > 3% (Error)
   - Maintainability Rating worse than A (Error)
   - Reliability Rating worse than A (Error)
   - Security Rating worse than A (Error)
   - Security Hotspots Reviewed < 100% (Error)

### Set as Default

1. Select your quality gate
2. Click "Set as Default"

## 4. Configure SonarQube in Jenkins

### Install SonarQube Scanner Plugin

1. Manage Jenkins → Manage Plugins
2. Available → Search "SonarQube Scanner"
3. Install without restart

### Configure SonarQube Server

1. Manage Jenkins → Configure System
2. Scroll to "SonarQube servers"
3. Add SonarQube:
   - Name: `SonarQube`
   - Server URL: `http://your-sonarqube-ip:9000`
   - Server authentication token: Select the credential with SonarQube token

### Configure SonarQube Scanner

1. Manage Jenkins → Global Tool Configuration
2. SonarQube Scanner:
   - Name: `SonarQube Scanner`
   - Install automatically: Yes
   - Version: Latest

## 5. Configure Webhook in SonarQube

This allows SonarQube to notify Jenkins about Quality Gate status.

1. Administration → Configuration → Webhooks
2. Create:
   - Name: `Jenkins`
   - URL: `http://your-jenkins-ip:8080/sonarqube-webhook/`
   - Secret: (optional, for security)

## 6. Quality Profiles

### Java Quality Profile

1. Quality Profiles → Java
2. Copy "Sonar way" profile
3. Name: `Strict Java Profile`
4. Activate additional rules:
   - All critical and blocker bugs
   - Security vulnerabilities
   - Code smells

### Set as Default

1. Select your profile
2. Set as Default

## 7. Configure Project Analysis Properties

Create `sonar-project.properties` in your project root:

```properties
# Project identification
sonar.projectKey=springboot-app
sonar.projectName=Spring Boot Application
sonar.projectVersion=1.0

# Source code location
sonar.sources=src/main/java
sonar.tests=src/test/java

# Java version
sonar.java.source=17
sonar.java.target=17

# Encoding
sonar.sourceEncoding=UTF-8

# Coverage
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
sonar.junit.reportPaths=target/surefire-reports

# Exclusions
sonar.exclusions=**/test/**,**/target/**
sonar.test.exclusions=**/test/**
```

## 8. Test SonarQube Integration

### Manual Analysis

```bash
# From your project directory
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=springboot-app \
  -Dsonar.host.url=http://your-sonarqube-ip:9000 \
  -Dsonar.login=your-token
```

### Verify Results

1. Go to SonarQube dashboard
2. Check project analysis results
3. Review issues, coverage, and quality gate status

## 9. Production Best Practices

### Security

```bash
# Use HTTPS in production
# Configure reverse proxy (Nginx example)
sudo apt install nginx

# Create Nginx config
sudo nano /etc/nginx/sites-available/sonarqube

# Add configuration:
server {
    listen 80;
    server_name sonarqube.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name sonarqube.yourdomain.com;

    ssl_certificate /etc/ssl/certs/your-cert.crt;
    ssl_certificate_key /etc/ssl/private/your-key.key;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Backup

```bash
# Backup SonarQube data
docker exec sonarqube-db pg_dump -U sonar sonarqube > sonarqube-backup-$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v sonarqube_data:/data -v $(pwd):/backup ubuntu tar czf /backup/sonarqube-data-backup.tar.gz /data
```

### Monitoring

```bash
# Check SonarQube health
curl http://localhost:9000/api/system/health

# Monitor logs
docker logs -f sonarqube
```

## Security and Authentication

### Production Authentication

For production environments, configure centralized authentication:

**LDAP/Active Directory:**
- Centralized user management
- Group-based permissions
- Single source of truth

**OAuth 2.0 (GitHub/GitLab):**
- Single Sign-On experience
- Modern authentication
- Better user experience

**API Tokens:**
- Use for CI/CD integration
- Rotate regularly
- Never commit to code

See [Authentication Integration Guide](07-authentication-integration.md) for detailed configuration.

### Quick Security Checklist

- ✓ Change default admin password
- ✓ Disable anonymous write access
- ✓ Configure quality gates
- ✓ Enable audit logging
- ✓ Use HTTPS in production
- ✓ Regular backups
- ✓ Update regularly

## Next Steps

Proceed to [Nexus Setup](04-nexus-setup.md)
