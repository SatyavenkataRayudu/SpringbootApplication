# Combined Server Setup (Development/Testing Only)

> **Warning**: This setup is for development and testing environments only. For production, use [separate servers](00-architecture-overview.md).

## Overview

Run Jenkins, SonarQube, and Nexus on a single EC2 instance using Docker containers.

**Pros:**
- Lower cost (~$80/month vs ~$95/month)
- Simpler to manage
- Good for learning and testing

**Cons:**
- Resource contention during builds
- Single point of failure
- Not suitable for production
- Limited scalability

## Server Requirements

**EC2 Instance:**
- Type: `t3.large` (2 vCPU, 8GB RAM minimum)
- Storage: 200GB SSD
- OS: Ubuntu 22.04 LTS

**Memory Allocation:**
- Jenkins: 3GB
- SonarQube: 3GB
- Nexus: 2GB

## Installation Steps

### 1. Launch EC2 Instance

```bash
# Launch t3.large instance with Ubuntu 22.04
# Security Group: Allow ports 22, 8080, 9000, 8081, 8082, 50000

# SSH into instance
ssh -i your-key.pem ubuntu@your-instance-ip
```

### 2. Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu

# Log out and back in for group changes to take effect
exit
# SSH back in
ssh -i your-key.pem ubuntu@your-instance-ip

# Verify Docker
docker --version
```

### 3. Configure System for SonarQube

```bash
# Increase virtual memory for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf
```

### 4. Create Docker Network

```bash
# Create shared network for all containers
docker network create cicd-network
```

### 5. Run PostgreSQL (for SonarQube)

```bash
docker run -d \
  --name sonarqube-db \
  --network cicd-network \
  --restart unless-stopped \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  -e POSTGRES_DB=sonarqube \
  -v postgresql_data:/var/lib/postgresql/data \
  postgres:15-alpine

# Verify
docker logs sonarqube-db
```

### 6. Run SonarQube

```bash
docker run -d \
  --name sonarqube \
  --network cicd-network \
  --restart unless-stopped \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  --memory="3g" \
  --memory-swap="3g" \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:lts-community

# Check logs (takes 2-3 minutes to start)
docker logs -f sonarqube
# Wait for "SonarQube is operational"
```

### 7. Run Nexus

```bash
docker run -d \
  --name nexus \
  --network cicd-network \
  --restart unless-stopped \
  -p 8081:8081 \
  -p 8082:8082 \
  --memory="2g" \
  --memory-swap="2g" \
  -v nexus-data:/nexus-data \
  sonatype/nexus3:latest

# Check logs (takes 2-3 minutes to start)
docker logs -f nexus
# Wait for "Started Sonatype Nexus"

# Get initial admin password
docker exec nexus cat /nexus-data/admin.password
```

### 8. Run Jenkins

```bash
docker run -d \
  --name jenkins \
  --network cicd-network \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  --memory="3g" \
  --memory-swap="3g" \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --user root \
  jenkins/jenkins:lts

# Check logs
docker logs -f jenkins
# Look for initial admin password in logs

# Or get it directly
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 9. Install Additional Tools in Jenkins Container

```bash
# Enter Jenkins container
docker exec -it jenkins bash

# Install Docker CLI
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce-cli

# Install Maven
apt-get install -y maven

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install

# Install Trivy
apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install -y trivy

# Exit container
exit
```

## Access URLs

After all containers are running:

- **Jenkins**: `http://your-server-ip:8080`
- **SonarQube**: `http://your-server-ip:9000`
- **Nexus**: `http://your-server-ip:8081`
- **Nexus Docker**: `http://your-server-ip:8082`

## Configuration

### Jenkins Configuration

Since all tools are on the same server, use container names for URLs:

```
SonarQube URL: http://sonarqube:9000
Nexus URL: http://nexus:8081
Nexus Docker: http://nexus:8082
```

Or use the host IP:

```
SonarQube URL: http://your-server-ip:9000
Nexus URL: http://your-server-ip:8081
Nexus Docker: http://your-server-ip:8082
```

### Docker Registry Configuration

```bash
# On the host (not in container)
sudo nano /etc/docker/daemon.json

# Add:
{
  "insecure-registries": ["your-server-ip:8082", "nexus:8082"]
}

# Restart Docker
sudo systemctl restart docker

# Restart all containers
docker restart jenkins sonarqube nexus sonarqube-db
```

## Management Commands

### Check All Containers

```bash
docker ps -a
```

### View Logs

```bash
docker logs jenkins
docker logs sonarqube
docker logs nexus
docker logs sonarqube-db
```

### Restart Containers

```bash
docker restart jenkins
docker restart sonarqube
docker restart nexus
```

### Stop All

```bash
docker stop jenkins sonarqube nexus sonarqube-db
```

### Start All

```bash
docker start sonarqube-db
sleep 10
docker start sonarqube nexus jenkins
```

### Backup All Data

```bash
# Create backup directory
mkdir -p ~/backups

# Backup Jenkins
docker run --rm \
  -v jenkins_home:/data \
  -v ~/backups:/backup \
  ubuntu tar czf /backup/jenkins-backup-$(date +%Y%m%d).tar.gz /data

# Backup SonarQube database
docker exec sonarqube-db pg_dump -U sonar sonarqube > ~/backups/sonarqube-backup-$(date +%Y%m%d).sql

# Backup Nexus
docker run --rm \
  -v nexus-data:/data \
  -v ~/backups:/backup \
  ubuntu tar czf /backup/nexus-backup-$(date +%Y%m%d).tar.gz /data
```

## Monitoring Resources

### Check Memory Usage

```bash
docker stats
```

### Check Disk Usage

```bash
df -h
docker system df
```

### Clean Up Unused Resources

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (careful!)
docker volume prune

# Remove unused networks
docker network prune
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs container-name

# Check if port is already in use
sudo netstat -tulpn | grep :8080

# Remove and recreate container
docker stop container-name
docker rm container-name
# Run the docker run command again
```

### Out of Memory

```bash
# Check memory
free -h

# Reduce container memory limits
docker update --memory="2g" jenkins
docker update --memory="2g" sonarqube
docker update --memory="1g" nexus

# Restart containers
docker restart jenkins sonarqube nexus
```

### Disk Full

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a --volumes

# Clean logs
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

## Docker Compose Alternative

For easier management, create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  sonarqube-db:
    image: postgres:15-alpine
    container_name: sonarqube-db
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonarqube
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    networks:
      - cicd-network
    restart: unless-stopped

  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    networks:
      - cicd-network
    restart: unless-stopped
    mem_limit: 3g

  nexus:
    image: sonatype/nexus3:latest
    container_name: nexus
    ports:
      - "8081:8081"
      - "8082:8082"
    volumes:
      - nexus-data:/nexus-data
    networks:
      - cicd-network
    restart: unless-stopped
    mem_limit: 2g

  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - cicd-network
    restart: unless-stopped
    mem_limit: 3g

networks:
  cicd-network:
    driver: bridge

volumes:
  postgresql_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  nexus-data:
  jenkins_home:
```

**Usage:**

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# Restart specific service
docker-compose restart jenkins
```

## Migration to Separate Servers

When ready to move to production:

1. Backup all data (see backup commands above)
2. Provision 3 separate EC2 instances
3. Follow individual setup guides:
   - [Jenkins Setup](02-jenkins-setup.md)
   - [SonarQube Setup](03-sonarqube-setup.md)
   - [Nexus Setup](04-nexus-setup.md)
4. Restore data to new servers
5. Update Jenkins configuration with new URLs

## Next Steps

After all containers are running:

1. Configure each tool following their respective guides
2. Set up authentication (see [Authentication Integration](07-authentication-integration.md))
3. Create Jenkins pipeline
4. Test the complete CI/CD flow

## Summary

This combined setup is perfect for:
- Learning the CI/CD pipeline
- Development environments
- Testing configurations
- Small personal projects

For production, always use separate servers for better reliability, performance, and scalability.
