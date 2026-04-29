# SonarQube Setup on EC2 Ubuntu (Native Installation)

Complete guide for installing SonarQube directly on Ubuntu 22.04 without Docker.

## Server Requirements

**EC2 Instance:**
- Instance Type: `t3.medium` (2 vCPU, 4GB RAM minimum)
- Storage: 50GB SSD
- OS: Ubuntu 22.04 LTS
- Security Group: Allow ports 22 (SSH), 9000 (SonarQube)

## Step 1: Connect to EC2 Instance

```bash
# SSH to your SonarQube server
ssh -i your-key.pem ubuntu@your-sonarqube-ip
```

## Step 2: Update System

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y wget unzip curl
```

## Step 3: Install Java 17

SonarQube requires Java 17.

```bash
# Install OpenJDK 17
sudo apt install -y openjdk-17-jdk

# Verify installation
java -version

# Set JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" | sudo tee -a /etc/environment
source /etc/environment

# Verify JAVA_HOME
echo $JAVA_HOME
```

## Step 4: Install and Configure PostgreSQL

SonarQube requires a database. PostgreSQL is recommended.

### Install PostgreSQL

```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify PostgreSQL is running
sudo systemctl status postgresql
```

### Create SonarQube Database and User

```bash
# Switch to postgres user
sudo -i -u postgres

# Create database and user
psql << EOF
CREATE USER sonar WITH ENCRYPTED PASSWORD 'sonar';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q
EOF

# Exit postgres user
exit

# Test connection
psql -U sonar -d sonarqube -h localhost -W
# Enter password: sonar
# Type \q to exit
```

### Configure PostgreSQL for SonarQube

```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/14/main/postgresql.conf

# Find and modify these lines (uncomment if needed):
listen_addresses = 'localhost'
max_connections = 300

# Save and exit (Ctrl+X, Y, Enter)

# Edit pg_hba.conf for authentication
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add this line before other rules:
host    sonarqube       sonar           127.0.0.1/32            md5

# Save and exit

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Step 5: Configure System Settings

SonarQube uses Elasticsearch internally, which requires specific system settings.

```bash
# Increase virtual memory
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
sudo sysctl -w vm.swappiness=1

# Make changes permanent
sudo tee -a /etc/sysctl.conf << EOF
vm.max_map_count=262144
fs.file-max=65536
vm.swappiness=1
EOF

# Increase ulimit
sudo tee -a /etc/security/limits.conf << EOF
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF

# Apply changes
sudo sysctl -p
```

## Step 6: Download and Install SonarQube

```bash
# Create sonarqube user
sudo useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube

# Download SonarQube (LTS version)
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.4.87374.zip

# Unzip SonarQube
sudo unzip sonarqube-9.9.4.87374.zip -d /opt

# Move to standard location
sudo mv /opt/sonarqube-9.9.4.87374 /opt/sonarqube

# Set ownership
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Clean up
rm sonarqube-9.9.4.87374.zip
```

## Step 7: Configure SonarQube

### Edit SonarQube Configuration

```bash
# Edit sonar.properties
sudo nano /opt/sonarqube/conf/sonar.properties
```

Find and modify these lines (uncomment by removing #):

```properties
# Database Configuration
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube

# Web Server Configuration
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch Configuration
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m

# Logging
sonar.log.level=INFO
sonar.path.logs=logs
```

Save and exit (Ctrl+X, Y, Enter).

### Configure SonarQube Wrapper

```bash
# Edit wrapper configuration
sudo nano /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Verify RUN_AS_USER is set (should be near the top)
# If not present, add:
RUN_AS_USER=sonarqube
```

## Step 8: Create Systemd Service

Create a systemd service for automatic startup.

```bash
# Create service file
sudo nano /etc/systemd/system/sonarqube.service
```

Add the following content:

```ini
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
ExecReload=/opt/sonarqube/bin/linux-x86-64/sonar.sh restart

User=sonarqube
Group=sonarqube
Restart=on-failure
RestartSec=10

LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

Save and exit.

## Step 9: Start SonarQube

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable SonarQube to start on boot
sudo systemctl enable sonarqube

# Start SonarQube
sudo systemctl start sonarqube

# Check status
sudo systemctl status sonarqube

# Monitor logs (takes 2-3 minutes to start)
sudo tail -f /opt/sonarqube/logs/sonar.log

# Wait for this message:
# "SonarQube is operational"
```

## Step 10: Verify Installation

```bash
# Check if SonarQube is listening on port 9000
sudo netstat -tulpn | grep 9000

# Check SonarQube health
curl http://localhost:9000/api/system/health

# Expected output: {"health":"GREEN","causes":[]}
```

## Step 11: Access SonarQube Web Interface

1. Open browser: `http://your-sonarqube-ip:9000`
2. Wait for SonarQube to fully start (may take 2-3 minutes)
3. Default credentials:
   - Username: `admin`
   - Password: `admin`
4. You'll be prompted to change the password

## Step 12: Initial Configuration

### Change Admin Password

1. Login with admin/admin
2. Follow the prompt to change password
3. Use a strong password (save it securely)

### Create Authentication Token for Jenkins

1. Click on your profile (top right) → My Account
2. Security tab
3. Generate Token:
   - Name: `jenkins-token`
   - Type: `Global Analysis Token`
   - Expires: No expiration (or set as needed)
4. Copy and save the token securely

### Create Project

1. Click "Create Project" → "Manually"
2. Project key: `springboot-app`
3. Display name: `Spring Boot Application`
4. Click "Set Up"
5. Choose "With Jenkins"

## Step 13: Configure Quality Gates

### Create Custom Quality Gate

1. Quality Gates → Create
2. Name: `Strict Quality Gate`
3. Add Conditions:
   - Coverage < 80% → Error
   - Duplicated Lines (%) > 3% → Error
   - Maintainability Rating worse than A → Error
   - Reliability Rating worse than A → Error
   - Security Rating worse than A → Error
   - Security Hotspots Reviewed < 100% → Error

4. Set as Default

## Step 14: Configure Webhook for Jenkins

This allows SonarQube to notify Jenkins about Quality Gate status.

1. Administration → Configuration → Webhooks
2. Create:
   - Name: `Jenkins`
   - URL: `http://your-jenkins-ip:8080/sonarqube-webhook/`
   - Secret: (optional)
3. Save

## Step 15: Configure Quality Profile

### Java Quality Profile

1. Quality Profiles → Java
2. Copy "Sonar way" profile
3. Name: `Strict Java Profile`
4. Activate additional rules as needed
5. Set as Default

## Step 16: Test SonarQube

### Manual Analysis Test

On your local machine or Jenkins server:

```bash
# Install Maven (if not already installed)
sudo apt install -y maven

# Clone a test project
git clone https://github.com/your-repo/springboot-app.git
cd springboot-app

# Run SonarQube analysis
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=springboot-app \
  -Dsonar.host.url=http://your-sonarqube-ip:9000 \
  -Dsonar.login=your-token-here

# Check results in SonarQube web interface
```

## Troubleshooting

### SonarQube Won't Start

```bash
# Check logs
sudo tail -f /opt/sonarqube/logs/sonar.log
sudo tail -f /opt/sonarqube/logs/es.log
sudo tail -f /opt/sonarqube/logs/web.log

# Check if port 9000 is already in use
sudo netstat -tulpn | grep 9000

# Check system resources
free -h
df -h

# Verify Java installation
java -version

# Check PostgreSQL connection
psql -U sonar -d sonarqube -h localhost -W
```

### Elasticsearch Issues

```bash
# Check vm.max_map_count
sysctl vm.max_map_count
# Should be 262144

# If not, set it
sudo sysctl -w vm.max_map_count=262144

# Check Elasticsearch logs
sudo tail -f /opt/sonarqube/logs/es.log
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql -U sonar -d sonarqube -h localhost -W

# Check PostgreSQL is running
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Verify database exists
sudo -u postgres psql -c "\l" | grep sonarqube
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Check file permissions
ls -la /opt/sonarqube
```

### Out of Memory

```bash
# Check memory usage
free -h

# Increase Elasticsearch heap size
sudo nano /opt/sonarqube/conf/sonar.properties

# Modify:
sonar.search.javaOpts=-Xmx1g -Xms1g -XX:MaxDirectMemorySize=512m

# Restart SonarQube
sudo systemctl restart sonarqube
```

## Maintenance

### Start/Stop/Restart SonarQube

```bash
# Start
sudo systemctl start sonarqube

# Stop
sudo systemctl stop sonarqube

# Restart
sudo systemctl restart sonarqube

# Status
sudo systemctl status sonarqube

# View logs
sudo journalctl -u sonarqube -f
```

### Backup SonarQube

```bash
# Stop SonarQube
sudo systemctl stop sonarqube

# Backup database
sudo -u postgres pg_dump sonarqube > sonarqube-backup-$(date +%Y%m%d).sql

# Backup SonarQube data directory
sudo tar czf sonarqube-data-backup-$(date +%Y%m%d).tar.gz /opt/sonarqube/data

# Backup configuration
sudo tar czf sonarqube-conf-backup-$(date +%Y%m%d).tar.gz /opt/sonarqube/conf

# Start SonarQube
sudo systemctl start sonarqube
```

### Update SonarQube

```bash
# Stop SonarQube
sudo systemctl stop sonarqube

# Backup current installation
sudo cp -r /opt/sonarqube /opt/sonarqube-backup

# Download new version
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-X.X.X.zip

# Unzip and replace
sudo unzip sonarqube-X.X.X.zip -d /opt
sudo mv /opt/sonarqube-X.X.X /opt/sonarqube-new

# Copy configuration
sudo cp /opt/sonarqube/conf/sonar.properties /opt/sonarqube-new/conf/

# Replace old installation
sudo mv /opt/sonarqube /opt/sonarqube-old
sudo mv /opt/sonarqube-new /opt/sonarqube

# Set ownership
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Start SonarQube
sudo systemctl start sonarqube

# Monitor logs
sudo tail -f /opt/sonarqube/logs/sonar.log
```

### Monitor SonarQube

```bash
# Check system health
curl http://localhost:9000/api/system/health

# Check system status
curl http://localhost:9000/api/system/status

# Monitor resource usage
htop

# Check disk usage
df -h

# Check logs
sudo tail -f /opt/sonarqube/logs/sonar.log
```

## Security Best Practices

### Configure Firewall

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22

# Allow SonarQube
sudo ufw allow 9000

# Check status
sudo ufw status
```

### Use HTTPS (Production)

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
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

# Enable site
sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check SonarQube version
curl http://localhost:9000/api/system/status | grep version

# Subscribe to SonarQube security announcements
# https://www.sonarsource.com/products/sonarqube/downloads/
```

## Performance Tuning

### For t3.medium (4GB RAM)

```bash
# Edit sonar.properties
sudo nano /opt/sonarqube/conf/sonar.properties

# Optimize for 4GB RAM:
sonar.web.javaOpts=-Xmx512m -Xms128m
sonar.ce.javaOpts=-Xmx512m -Xms128m
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m

# Restart
sudo systemctl restart sonarqube
```

### For t3.large (8GB RAM)

```bash
# Optimize for 8GB RAM:
sonar.web.javaOpts=-Xmx1g -Xms256m
sonar.ce.javaOpts=-Xmx1g -Xms256m
sonar.search.javaOpts=-Xmx1g -Xms1g -XX:MaxDirectMemorySize=512m
```

## Next Steps

1. Configure Jenkins integration (see [Jenkins Setup](02-jenkins-setup.md))
2. Set up authentication (see [Authentication Integration](07-authentication-integration.md))
3. Proceed to [Nexus Setup](04-nexus-setup.md)

## Quick Reference

**Service Management:**
```bash
sudo systemctl start sonarqube
sudo systemctl stop sonarqube
sudo systemctl restart sonarqube
sudo systemctl status sonarqube
```

**Logs:**
```bash
sudo tail -f /opt/sonarqube/logs/sonar.log
sudo tail -f /opt/sonarqube/logs/web.log
sudo tail -f /opt/sonarqube/logs/es.log
```

**Configuration:**
- Main config: `/opt/sonarqube/conf/sonar.properties`
- Data directory: `/opt/sonarqube/data`
- Logs directory: `/opt/sonarqube/logs`

**URLs:**
- Web UI: `http://your-ip:9000`
- Health check: `http://your-ip:9000/api/system/health`
- Status: `http://your-ip:9000/api/system/status`
