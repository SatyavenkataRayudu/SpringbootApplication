# Nexus Repository Manager Setup

## Installation Options

Choose your preferred installation method:

1. **Docker Installation (Recommended for Quick Setup)** - See below
2. **Native Installation (Recommended for Production)** - See [Native Installation Guide](04-nexus-setup-native.md)

**Docker Pros:** Quick setup, easy management, isolated environment
**Native Pros:** Better performance, easier troubleshooting, production-ready, better resource control

---

## Docker Installation (Quick Setup)

## Server Requirements

### Recommended Instance Sizing

**Minimum Requirements:**
- Instance Type: `t3.small` (2 vCPU, 2GB RAM)
- Storage: 50GB SSD minimum (grows with artifacts)
- OS: Ubuntu 22.04 LTS

**Production Recommendations:**
- Instance Type: `t3.medium` (2 vCPU, 4GB RAM)
- Storage: 100-500GB SSD depending on artifact retention
- Reason: Nexus is primarily I/O bound for artifact storage and retrieval

**Why Not Identical Servers:**
- Nexus is less CPU-intensive than Jenkins or SonarQube
- Primarily serves artifacts (storage and network focused)
- Can start smaller and scale based on usage
- Storage requirements grow over time, not compute

### Cost Considerations

**Separate Server (Recommended):**
- Independent storage scaling
- Better artifact availability
- No impact from Jenkins builds or SonarQube analysis
- Easier backup and disaster recovery

**Combined Setup (Dev/Test Only):**
- Can share t3.large (2 vCPU, 8GB RAM) with other tools
- Lowest resource consumer of the three tools
- Good candidate for consolidation if budget is tight
- Monitor disk I/O and storage growth

### Storage Planning

- **Maven artifacts**: Plan for 10-50GB initially
- **Docker images**: Can grow rapidly (100GB+)
- **Retention policies**: Configure cleanup to manage growth
- **Backup strategy**: Regular backups of nexus-data volume

## 1. Install Nexus using Docker

### Run Nexus Container

```bash
# Create volume for persistent data
docker volume create nexus-data

# Run Nexus
docker run -d \
  --name nexus \
  -p 8081:8081 \
  -p 8082:8082 \
  -v nexus-data:/nexus-data \
  sonatype/nexus3:latest

# Check logs (Nexus takes 2-3 minutes to start)
docker logs -f nexus

# Get initial admin password
docker exec nexus cat /nexus-data/admin.password
```

## 2. Initial Configuration

### Access Nexus

1. Open browser: `http://your-server-ip:8081`
2. Click "Sign In" (top right)
3. Username: `admin`
4. Password: Get from command above
5. Complete setup wizard:
   - Change admin password
   - Configure anonymous access (Enable for read)
   - Finish

## 3. Create Repositories

### Maven Hosted Repository (Releases)

1. Settings (gear icon) → Repositories → Create repository
2. Recipe: `maven2 (hosted)`
3. Configuration:
   - Name: `maven-releases`
   - Version policy: `Release`
   - Layout policy: `Strict`
   - Deployment policy: `Allow redeploy`
4. Create repository

### Maven Hosted Repository (Snapshots)

1. Create repository → maven2 (hosted)
2. Configuration:
   - Name: `maven-snapshots`
   - Version policy: `Snapshot`
   - Layout policy: `Strict`
   - Deployment policy: `Allow redeploy`
3. Create repository

### Docker Hosted Repository

1. Create repository → docker (hosted)
2. Configuration:
   - Name: `docker-hosted`
   - HTTP: `8082`
   - Enable Docker V1 API: No
   - Deployment policy: `Allow redeploy`
3. Create repository

### Maven Proxy Repository (Maven Central)

1. Create repository → maven2 (proxy)
2. Configuration:
   - Name: `maven-central`
   - Version policy: `Release`
   - Remote storage: `https://repo1.maven.org/maven2/`
3. Create repository

### Maven Group Repository

1. Create repository → maven2 (group)
2. Configuration:
   - Name: `maven-public`
   - Member repositories:
     - maven-releases
     - maven-snapshots
     - maven-central
3. Create repository

## 4. Configure Maven Settings

### Update Maven settings.xml

Create or update `~/.m2/settings.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
  
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>admin</username>
      <password>your-nexus-password</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>admin</username>
      <password>your-nexus-password</password>
    </server>
  </servers>
  
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://your-nexus-ip:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
  
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>http://your-nexus-ip:8081/repository/maven-public/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>http://your-nexus-ip:8081/repository/maven-public/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

### Configure on Jenkins Server

```bash
# SSH to Jenkins server
sudo su - jenkins

# Create .m2 directory
mkdir -p ~/.m2

# Create settings.xml
nano ~/.m2/settings.xml
# Paste the configuration above
```

## 5. Configure Docker Registry

### Configure Docker Daemon

```bash
# Add insecure registry (for HTTP, use HTTPS in production)
sudo nano /etc/docker/daemon.json

# Add:
{
  "insecure-registries": ["your-nexus-ip:8082"]
}

# Restart Docker
sudo systemctl restart docker
```

### Test Docker Push

```bash
# Login to Nexus Docker registry
docker login your-nexus-ip:8082
# Username: admin
# Password: your-nexus-password

# Tag and push test image
docker pull alpine:latest
docker tag alpine:latest your-nexus-ip:8082/alpine:test
docker push your-nexus-ip:8082/alpine:test
```

## 6. Create Nexus User for Jenkins

### Create Deployment User

1. Settings → Security → Users → Create local user
2. Configuration:
   - ID: `jenkins-deploy`
   - First name: `Jenkins`
   - Last name: `Deploy`
   - Email: `jenkins@example.com`
   - Password: Strong password
   - Status: `Active`
   - Roles: `nx-admin` (or create custom role)
3. Create user

### Create Custom Role (Recommended)

1. Settings → Security → Roles → Create role
2. Configuration:
   - Type: `Nexus role`
   - Role ID: `jenkins-deployer`
   - Role name: `Jenkins Deployer`
   - Privileges:
     - `nx-repository-view-maven2-*-*`
     - `nx-repository-view-docker-*-*`
     - `nx-repository-admin-maven2-maven-releases-*`
     - `nx-repository-admin-maven2-maven-snapshots-*`
     - `nx-repository-admin-docker-docker-hosted-*`
3. Create role
4. Assign role to `jenkins-deploy` user

## 7. Configure Cleanup Policies

### Create Cleanup Policy

1. Settings → Repository → Cleanup Policies → Create
2. Configuration:
   - Name: `cleanup-old-snapshots`
   - Format: `maven2`
   - Criteria:
     - Last downloaded: 30 days
     - Release type: `Snapshots`
3. Create

### Apply to Repository

1. Repositories → maven-snapshots → Settings
2. Cleanup Policies: Select `cleanup-old-snapshots`
3. Save

### Create Cleanup Task

1. Settings → System → Tasks → Create task
2. Type: `Admin - Compact blob store`
3. Schedule: Daily at 2 AM
4. Create

## 8. Test Maven Deployment

```bash
# From your Spring Boot project
mvn clean deploy -DskipTests

# Verify in Nexus
# Browse → maven-releases or maven-snapshots
```

## 9. Backup and Restore

### Backup Nexus Data

```bash
# Stop Nexus
docker stop nexus

# Backup data volume
docker run --rm \
  -v nexus-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/nexus-backup-$(date +%Y%m%d).tar.gz /data

# Start Nexus
docker start nexus
```

### Restore from Backup

```bash
# Stop Nexus
docker stop nexus

# Restore data
docker run --rm \
  -v nexus-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/nexus-backup-YYYYMMDD.tar.gz -C /

# Start Nexus
docker start nexus
```

## 10. Production Best Practices

### Enable HTTPS

```bash
# Generate SSL certificate or use Let's Encrypt
# Configure Nexus to use HTTPS

# Update nexus.properties
docker exec -it nexus bash
vi /nexus-data/etc/nexus.properties

# Add:
application-port-ssl=8443
nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-https.xml
```

### Monitoring

```bash
# Check Nexus health
curl http://localhost:8081/service/rest/v1/status

# Monitor disk usage
docker exec nexus df -h /nexus-data

# View logs
docker logs nexus
```

### Resource Limits

```bash
# Run with resource limits
docker run -d \
  --name nexus \
  -p 8081:8081 \
  -p 8082:8082 \
  -v nexus-data:/nexus-data \
  -e INSTALL4J_ADD_VM_PARAMS="-Xms2g -Xmx2g -XX:MaxDirectMemorySize=2g" \
  --memory="4g" \
  --cpus="2" \
  sonatype/nexus3:latest
```

## Security and Authentication

### Production Authentication

For production environments, configure centralized authentication:

**LDAP/Active Directory:**
- Centralized user management
- Map LDAP groups to Nexus roles
- Single source of truth

**Local Users + Roles:**
- Create service accounts for Jenkins
- Use strong passwords
- Role-based access control

**API Tokens:**
- Use NuGet API keys for programmatic access
- Rotate credentials regularly
- Never hardcode in pipelines

See [Authentication Integration Guide](07-authentication-integration.md) for detailed configuration.

### Quick Security Checklist

- ✓ Change default admin password
- ✓ Create deployment user for Jenkins
- ✓ Configure anonymous access (read-only if needed)
- ✓ Enable HTTPS in production
- ✓ Configure cleanup policies
- ✓ Regular backups
- ✓ Monitor disk usage
- ✓ Update regularly

### Recommended User Setup

```
Users:
- admin: Full administration (human access only)
- jenkins-deploy: CI/CD deployments (service account)
- developers: Read access to all, write to snapshots

Roles:
- nx-admin: Full access
- nx-deployer: Deploy to releases and snapshots
- nx-developer: Read all, write snapshots only
- nx-viewer: Read-only access
```

## Next Steps

Proceed to [AWS EKS Setup](05-eks-setup.md)
