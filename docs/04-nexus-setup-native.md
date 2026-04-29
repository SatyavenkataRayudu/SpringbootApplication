# Nexus Repository Manager Setup on EC2 Ubuntu (Native Installation)

Complete guide for installing Nexus Repository Manager directly on Ubuntu 22.04 without Docker.

## Server Requirements

**EC2 Instance:**
- Instance Type: `t3.small` (2 vCPU, 2GB RAM minimum) or `t3.medium` (4GB RAM recommended)
- Storage: 100-500GB SSD (grows with artifacts)
- OS: Ubuntu 22.04 LTS
- Security Group: Allow ports 22 (SSH), 8081 (Nexus UI), 8082 (Docker registry)

## Step 1: Connect to EC2 Instance

```bash
# SSH to your Nexus server
ssh -i your-key.pem ubuntu@your-nexus-ip
```

## Step 2: Update System

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y wget curl vim
```

## Step 3: Install Java 8

Nexus requires Java 8 (OpenJDK 8).

```bash
# Install OpenJDK 8
sudo apt install -y openjdk-8-jdk

# Verify installation
java -version

# Should show: openjdk version "1.8.0_xxx"

# Set JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /etc/environment
source /etc/environment

# Verify JAVA_HOME
echo $JAVA_HOME
```

## Step 4: Create Nexus User

Create a dedicated user to run Nexus (security best practice).

```bash
# Create nexus user
sudo useradd -r -m -U -d /opt/nexus -s /bin/bash nexus

# Set password (optional, for SSH access)
sudo passwd nexus
```

## Step 5: Download and Install Nexus

```bash
# Download Nexus (latest version)
cd /opt
sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz

# Extract Nexus
sudo tar -xvzf latest-unix.tar.gz

# Rename for easier management
sudo mv nexus-3.* nexus

# Nexus creates two directories:
# /opt/nexus - Application files
# /opt/sonatype-work - Data directory

# Set ownership
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

# Clean up
sudo rm latest-unix.tar.gz
```

## Step 6: Configure Nexus

### Set Run As User

```bash
# Edit nexus.rc to run as nexus user
sudo nano /opt/nexus/bin/nexus.rc
```

Uncomment and set:
```
run_as_user="nexus"
```

Save and exit (Ctrl+X, Y, Enter).

### Configure Nexus Properties

```bash
# Edit nexus.properties
sudo nano /opt/nexus/bin/nexus.vmoptions
```

Adjust memory settings based on your instance:

**For t3.small (2GB RAM):**
```
-Xms512m
-Xmx512m
-XX:MaxDirectMemorySize=512m
```

**For t3.medium (4GB RAM):**
```
-Xms1024m
-Xmx1024m
-XX:MaxDirectMemorySize=1024m
```

**For t3.large (8GB RAM):**
```
-Xms2048m
-Xmx2048m
-XX:MaxDirectMemorySize=2048m
```

Save and exit.

### Configure Application Port (Optional)

```bash
# Edit nexus-default.properties
sudo nano /opt/nexus/etc/nexus-default.properties
```

Default settings (usually fine):
```properties
application-port=8081
application-host=0.0.0.0
nexus-context-path=/
```

For Docker registry, you'll configure port 8082 later in the Nexus UI.

## Step 7: Create Systemd Service

Create a systemd service for automatic startup.

```bash
# Create service file
sudo nano /etc/systemd/system/nexus.service
```

Add the following content:

```ini
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
ExecReload=/opt/nexus/bin/nexus restart
User=nexus
Group=nexus
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Save and exit.

## Step 8: Start Nexus

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable Nexus to start on boot
sudo systemctl enable nexus

# Start Nexus
sudo systemctl start nexus

# Check status
sudo systemctl status nexus

# Monitor logs (Nexus takes 2-3 minutes to start)
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log

# Wait for this message:
# "Started Sonatype Nexus OSS"
```

## Step 9: Verify Installation

```bash
# Check if Nexus is listening on port 8081
sudo netstat -tulpn | grep 8081

# Check Nexus process
ps aux | grep nexus

# Test local access
curl http://localhost:8081
```

## Step 10: Get Initial Admin Password

```bash
# Get the initial admin password
sudo cat /opt/sonatype-work/nexus3/admin.password

# Copy this password - you'll need it for first login
```

## Step 11: Access Nexus Web Interface

1. Open browser: `http://your-nexus-ip:8081`
2. Wait for Nexus to fully start (may take 2-3 minutes)
3. Click "Sign In" (top right)
4. Username: `admin`
5. Password: Use the password from `/opt/sonatype-work/nexus3/admin.password`

## Step 12: Initial Setup Wizard

1. **Change Admin Password**
   - Enter new password
   - Confirm password
   - Click "Next"

2. **Configure Anonymous Access**
   - Enable: For read-only access (recommended for development)
   - Disable: For production (more secure)
   - Click "Next"

3. **Finish Setup**
   - Click "Finish"

4. **Delete Initial Password File**
   ```bash
   sudo rm /opt/sonatype-work/nexus3/admin.password
   ```

## Step 13: Create Repositories

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

### Maven Proxy Repository (Maven Central)

1. Create repository → maven2 (proxy)
2. Configuration:
   - Name: `maven-central`
   - Version policy: `Release`
   - Remote storage: `https://repo1.maven.org/maven2/`
   - Auto-blocking enabled: Yes
3. Create repository

### Maven Group Repository

1. Create repository → maven2 (group)
2. Configuration:
   - Name: `maven-public`
   - Member repositories (in order):
     - maven-releases
     - maven-snapshots
     - maven-central
3. Create repository

### Docker Hosted Repository

1. Create repository → docker (hosted)
2. Configuration:
   - Name: `docker-hosted`
   - HTTP: `8082`
   - Enable Docker V1 API: No
   - Deployment policy: `Allow redeploy`
   - Blob store: `default`
3. Create repository

## Step 14: Configure Firewall

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22

# Allow Nexus UI
sudo ufw allow 8081

# Allow Docker registry
sudo ufw allow 8082

# Check status
sudo ufw status
```

## Step 15: Configure Docker Registry Access

### On Jenkins Server (or any Docker client)

```bash
# Add insecure registry (for HTTP, use HTTPS in production)
sudo nano /etc/docker/daemon.json
```

Add:
```json
{
  "insecure-registries": ["your-nexus-ip:8082"]
}
```

```bash
# Restart Docker
sudo systemctl restart docker

# Login to Nexus Docker registry
docker login your-nexus-ip:8082
# Username: admin
# Password: your-nexus-password

# Test push
docker pull alpine:latest
docker tag alpine:latest your-nexus-ip:8082/alpine:test
docker push your-nexus-ip:8082/alpine:test
```

## Step 16: Create Deployment User for Jenkins

### Create User

1. Settings → Security → Users → Create local user
2. Configuration:
   - ID: `jenkins-deploy`
   - First name: `Jenkins`
   - Last name: `Deploy`
   - Email: `jenkins@example.com`
   - Password: Strong password
   - Status: `Active`
3. Create user

### Create Custom Role

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

### Assign Role to User

1. Settings → Security → Users
2. Select `jenkins-deploy`
3. Roles → Add `jenkins-deployer`
4. Save

## Step 17: Configure Maven Settings

### On Jenkins Server

```bash
# SSH to Jenkins server
ssh -i your-key.pem ubuntu@jenkins-server-ip

# Switch to jenkins user
sudo su - jenkins

# Create .m2 directory
mkdir -p ~/.m2

# Create settings.xml
nano ~/.m2/settings.xml
```

Add the following:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
  
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>jenkins-deploy</username>
      <password>your-jenkins-deploy-password</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>jenkins-deploy</username>
      <password>your-jenkins-deploy-password</password>
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

Save and exit.

## Step 18: Configure Cleanup Policies

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

## Step 19: Test Maven Deployment

```bash
# On Jenkins server or local machine with Maven
# Clone your Spring Boot project
git clone https://github.com/your-repo/springboot-app.git
cd springboot-app

# Add distribution management to pom.xml
nano pom.xml
```

Add before `</project>`:

```xml
<distributionManagement>
    <repository>
        <id>nexus-releases</id>
        <url>http://your-nexus-ip:8081/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
        <id>nexus-snapshots</id>
        <url>http://your-nexus-ip:8081/repository/maven-snapshots/</url>
    </snapshotRepository>
</distributionManagement>
```

```bash
# Deploy to Nexus
mvn clean deploy -DskipTests

# Verify in Nexus
# Browse → maven-releases or maven-snapshots
```

## Troubleshooting

### Nexus Won't Start

```bash
# Check logs
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log

# Check if port 8081 is already in use
sudo netstat -tulpn | grep 8081

# Check Java version
java -version
# Must be Java 8

# Check permissions
ls -la /opt/nexus
ls -la /opt/sonatype-work

# Fix permissions if needed
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work
```

### Out of Memory

```bash
# Check memory usage
free -h

# Increase heap size
sudo nano /opt/nexus/bin/nexus.vmoptions

# For t3.medium (4GB RAM):
-Xms1024m
-Xmx1024m
-XX:MaxDirectMemorySize=1024m

# Restart Nexus
sudo systemctl restart nexus
```

### Port Already in Use

```bash
# Check what's using port 8081
sudo lsof -i :8081

# Kill the process if needed
sudo kill -9 <PID>

# Or change Nexus port
sudo nano /opt/nexus/etc/nexus-default.properties
# Change application-port=8081 to another port
```

### Permission Denied Errors

```bash
# Fix ownership
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

# Check nexus user can access files
sudo -u nexus ls -la /opt/nexus
```

### Docker Registry Connection Issues

```bash
# On Docker client (Jenkins server)
# Check Docker daemon.json
cat /etc/docker/daemon.json

# Should include:
# "insecure-registries": ["your-nexus-ip:8082"]

# Restart Docker
sudo systemctl restart docker

# Test connection
curl http://your-nexus-ip:8082/v2/

# Should return: {}
```

## Maintenance

### Start/Stop/Restart Nexus

```bash
# Start
sudo systemctl start nexus

# Stop
sudo systemctl stop nexus

# Restart
sudo systemctl restart nexus

# Status
sudo systemctl status nexus

# View logs
sudo journalctl -u nexus -f
```

### Backup Nexus

```bash
# Stop Nexus
sudo systemctl stop nexus

# Backup data directory
sudo tar czf nexus-backup-$(date +%Y%m%d).tar.gz /opt/sonatype-work

# Backup configuration
sudo tar czf nexus-config-backup-$(date +%Y%m%d).tar.gz /opt/nexus/etc

# Start Nexus
sudo systemctl start nexus

# Copy backups to S3 (optional)
aws s3 cp nexus-backup-$(date +%Y%m%d).tar.gz s3://your-backup-bucket/
```

### Restore from Backup

```bash
# Stop Nexus
sudo systemctl stop nexus

# Restore data
sudo tar xzf nexus-backup-YYYYMMDD.tar.gz -C /

# Fix permissions
sudo chown -R nexus:nexus /opt/sonatype-work

# Start Nexus
sudo systemctl start nexus
```

### Update Nexus

```bash
# Stop Nexus
sudo systemctl stop nexus

# Backup current installation
sudo cp -r /opt/nexus /opt/nexus-backup
sudo cp -r /opt/sonatype-work /opt/sonatype-work-backup

# Download new version
cd /opt
sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz

# Extract
sudo tar -xvzf latest-unix.tar.gz

# Replace old installation
sudo rm -rf /opt/nexus
sudo mv nexus-3.* /opt/nexus

# Set ownership
sudo chown -R nexus:nexus /opt/nexus

# Start Nexus
sudo systemctl start nexus

# Monitor logs
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log
```

### Monitor Nexus

```bash
# Check system status
curl -u admin:password http://localhost:8081/service/rest/v1/status

# Check disk usage
df -h /opt/sonatype-work

# Monitor logs
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log

# Check resource usage
htop

# View all repositories
curl -u admin:password http://localhost:8081/service/rest/v1/repositories
```

## Security Best Practices

### Use HTTPS (Production)

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/nexus
```

Add:
```nginx
server {
    listen 80;
    server_name nexus.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name nexus.yourdomain.com;

    ssl_certificate /etc/ssl/certs/your-cert.crt;
    ssl_certificate_key /etc/ssl/private/your-key.key;

    client_max_body_size 1G;

    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/nexus /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Disable Anonymous Access (Production)

1. Settings → Security → Anonymous Access
2. Uncheck "Allow anonymous users to access the server"
3. Save

### Regular Security Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check Nexus version
curl -u admin:password http://localhost:8081/service/rest/v1/status | grep version

# Subscribe to Nexus security announcements
# https://support.sonatype.com/hc/en-us/sections/203012668-Security-Advisories
```

## Performance Tuning

### For t3.small (2GB RAM)

```bash
sudo nano /opt/nexus/bin/nexus.vmoptions

# Set:
-Xms512m
-Xmx512m
-XX:MaxDirectMemorySize=512m
```

### For t3.medium (4GB RAM)

```bash
# Set:
-Xms1024m
-Xmx1024m
-XX:MaxDirectMemorySize=1024m
```

### For t3.large (8GB RAM)

```bash
# Set:
-Xms2048m
-Xmx2048m
-XX:MaxDirectMemorySize=2048m
```

After changes:
```bash
sudo systemctl restart nexus
```

## Next Steps

1. Configure Jenkins integration (see [Jenkins Setup](02-jenkins-setup.md))
2. Set up authentication (see [Authentication Integration](07-authentication-integration.md))
3. Proceed to [AWS EKS Setup](05-eks-setup.md)

## Quick Reference

**Service Management:**
```bash
sudo systemctl start nexus
sudo systemctl stop nexus
sudo systemctl restart nexus
sudo systemctl status nexus
```

**Logs:**
```bash
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log
sudo tail -f /opt/sonatype-work/nexus3/log/request.log
```

**Configuration:**
- Installation: `/opt/nexus`
- Data directory: `/opt/sonatype-work`
- Config: `/opt/nexus/etc/nexus-default.properties`
- JVM options: `/opt/nexus/bin/nexus.vmoptions`

**URLs:**
- Web UI: `http://your-ip:8081`
- Docker Registry: `http://your-ip:8082`
- API: `http://your-ip:8081/service/rest/v1/`
- Status: `http://your-ip:8081/service/rest/v1/status`

**Default Credentials:**
- Username: `admin`
- Password: Check `/opt/sonatype-work/nexus3/admin.password` (first time only)
