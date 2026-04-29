#!/bin/bash

# Local deployment script for testing
set -e

echo "Building Spring Boot application..."
mvn clean package -DskipTests

echo "Building Docker image..."
docker build -t springboot-app:local .

echo "Running container..."
docker run -d --name springboot-app -p 8080:8080 springboot-app:local

echo "Waiting for application to start..."
sleep 10

echo "Testing application..."
curl http://localhost:8080/actuator/health

echo ""
echo "Application is running at http://localhost:8080"
echo "To stop: docker stop springboot-app && docker rm springboot-app"
