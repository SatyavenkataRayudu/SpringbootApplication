# Kubernetes ConfigMap Reference Guide

## What is a ConfigMap?

A **ConfigMap** is a Kubernetes object that stores **non-sensitive configuration data** as key-value pairs. It separates configuration from your application code.

## Why Use ConfigMap?

### 1. Separation of Configuration from Code
Instead of hardcoding values in your application, you store them externally.

**Without ConfigMap (Bad):**
```java
// Hardcoded in application
String serverPort = "8080";
String profile = "production";
```

**With ConfigMap (Good):**
```java
// Read from environment variables
String serverPort = System.getenv("SERVER_PORT");
String profile = System.getenv("SPRING_PROFILES_ACTIVE");
```

### 2. Environment-Specific Configuration
Different settings for dev, staging, production without changing code.

```yaml
# Development ConfigMap
data:
  SPRING_PROFILES_ACTIVE: "development"
  SERVER_PORT: "8080"

# Production ConfigMap
data:
  SPRING_PROFILES_ACTIVE: "production"
  SERVER_PORT: "8080"
```

### 3. Easy Updates Without Rebuilding
Change configuration without rebuilding Docker images.

---

## Project ConfigMap Explained

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: springboot-app-config
  namespace: production
data:
  # Spring Boot will use "production" profile
  # Loads application-production.properties or application-production.yml
  SPRING_PROFILES_ACTIVE: "production"
  
  # Application will run on port 8080
  SERVER_PORT: "8080"
  
  # Java memory settings
  # -Xmx512m = Maximum heap size 512MB
  # -Xms256m = Initial heap size 256MB
  JAVA_OPTS: "-Xmx512m -Xms256m"
```

### Configuration Values Breakdown

| Key | Value | Purpose |
|-----|-------|---------|
| `SPRING_PROFILES_ACTIVE` | `production` | Tells Spring Boot to use production profile (loads `application-production.yml`) |
| `SERVER_PORT` | `8080` | Port where the application listens for HTTP requests |
| `JAVA_OPTS` | `-Xmx512m -Xms256m` | Java memory settings: max 512MB, initial 256MB |

---

## How ConfigMap is Used in Deployment

In your `deployment.yaml`, you reference this ConfigMap:

### Method 1: Inject All Values as Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
spec:
  template:
    spec:
      containers:
      - name: springboot-app
        image: your-image:latest
        # Inject ALL ConfigMap values as environment variables
        envFrom:
        - configMapRef:
            name: springboot-app-config
```

### Method 2: Inject Specific Values

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
spec:
  template:
    spec:
      containers:
      - name: springboot-app
        image: your-image:latest
        env:
        # Inject specific values from ConfigMap
        - name: SPRING_PROFILES_ACTIVE
          valueFrom:
            configMapKeyRef:
              name: springboot-app-config
              key: SPRING_PROFILES_ACTIVE
        - name: SERVER_PORT
          valueFrom:
            configMapKeyRef:
              name: springboot-app-config
              key: SERVER_PORT
```

### Method 3: Mount as Volume (for files)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
spec:
  template:
    spec:
      containers:
      - name: springboot-app
        image: your-image:latest
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: springboot-app-config
```

---

## Real-World Use Cases

### Example 1: Change Log Level Without Redeploying

```yaml
# Original ConfigMap
data:
  LOG_LEVEL: "INFO"

# Update to debug issues
data:
  LOG_LEVEL: "DEBUG"
```

```powershell
# Update ConfigMap
kubectl apply -f configmap.yaml

# Restart pods to pick up changes
kubectl rollout restart deployment springboot-app -n production
```

### Example 2: Different Configs for Different Environments

**Development:**
```yaml
# dev-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: springboot-app-config
  namespace: development
data:
  SPRING_PROFILES_ACTIVE: "development"
  DATABASE_URL: "jdbc:postgresql://dev-db:5432/myapp"
  CACHE_ENABLED: "false"
  LOG_LEVEL: "DEBUG"
```

**Production:**
```yaml
# prod-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: springboot-app-config
  namespace: production
data:
  SPRING_PROFILES_ACTIVE: "production"
  DATABASE_URL: "jdbc:postgresql://prod-db:5432/myapp"
  CACHE_ENABLED: "true"
  LOG_LEVEL: "INFO"
```

### Example 3: Feature Flags

```yaml
data:
  FEATURE_NEW_UI: "true"
  FEATURE_BETA_API: "false"
  FEATURE_ANALYTICS: "true"
```

---

## ConfigMap vs Secret

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Purpose** | Non-sensitive data | Sensitive data |
| **Encoding** | Plain text | Base64 encoded |
| **Use Cases** | Database URLs, ports, feature flags | Passwords, API keys, certificates |
| **Visibility** | Visible in kubectl get | Partially hidden |
| **Examples** | Log levels, timeouts, URLs | DB passwords, OAuth tokens |

**Example:**

```yaml
# ConfigMap - Non-sensitive
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_HOST: "postgres.example.com"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "myapp"

---
# Secret - Sensitive
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DATABASE_PASSWORD: "cGFzc3dvcmQxMjM="  # base64: password123
  API_KEY: "YWJjZGVmZ2hpams="  # base64: abcdefghijk
```

---

## How Spring Boot Uses ConfigMap Values

### In application.yml or application.properties

```yaml
# application.yml
server:
  port: ${SERVER_PORT:8080}  # Uses SERVER_PORT from ConfigMap, defaults to 8080

spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:default}  # Uses SPRING_PROFILES_ACTIVE

logging:
  level:
    root: ${LOG_LEVEL:INFO}
```

### In Java Code

```java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AppConfig {
    
    @Value("${SERVER_PORT}")
    private String serverPort;
    
    @Value("${SPRING_PROFILES_ACTIVE}")
    private String activeProfile;
    
    @Value("${DATABASE_URL:jdbc:postgresql://localhost:5432/myapp}")
    private String databaseUrl;
    
    public void printConfig() {
        System.out.println("Server Port: " + serverPort);
        System.out.println("Active Profile: " + activeProfile);
        System.out.println("Database URL: " + databaseUrl);
    }
}
```

---

## Common kubectl Commands

### Create ConfigMap

```powershell
# From YAML file
kubectl apply -f configmap.yaml

# From literal values
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=DEBUG \
  --from-literal=SERVER_PORT=8080

# From file
kubectl create configmap app-config \
  --from-file=application.properties

# From directory (all files)
kubectl create configmap app-config \
  --from-file=./config-dir/
```

### View ConfigMap

```powershell
# List all ConfigMaps
kubectl get configmaps -n production

# View specific ConfigMap
kubectl get configmap springboot-app-config -n production

# View in YAML format
kubectl get configmap springboot-app-config -n production -o yaml

# View in JSON format
kubectl get configmap springboot-app-config -n production -o json

# Describe ConfigMap
kubectl describe configmap springboot-app-config -n production
```

### Edit ConfigMap

```powershell
# Edit interactively
kubectl edit configmap springboot-app-config -n production

# Update from file
kubectl apply -f configmap.yaml

# Patch specific value
kubectl patch configmap springboot-app-config -n production \
  -p '{"data":{"LOG_LEVEL":"DEBUG"}}'
```

### Delete ConfigMap

```powershell
# Delete specific ConfigMap
kubectl delete configmap springboot-app-config -n production

# Delete from file
kubectl delete -f configmap.yaml
```

### Restart Pods to Pick Up Changes

```powershell
# After updating ConfigMap, restart deployment
kubectl rollout restart deployment springboot-app -n production

# Check rollout status
kubectl rollout status deployment springboot-app -n production
```

---

## Best Practices

### 1. Use Descriptive Names
```yaml
# Good
name: springboot-app-config

# Bad
name: config
```

### 2. Organize by Environment
```yaml
# Development
name: springboot-app-config-dev

# Production
name: springboot-app-config-prod
```

### 3. Document Your Values
```yaml
data:
  # Maximum number of database connections
  DB_MAX_CONNECTIONS: "50"
  
  # Cache TTL in seconds
  CACHE_TTL: "3600"
  
  # Enable debug logging (true/false)
  DEBUG_MODE: "false"
```

### 4. Use Namespaces
```yaml
metadata:
  name: springboot-app-config
  namespace: production  # Isolate by environment
```

### 5. Version Your ConfigMaps
```yaml
metadata:
  name: springboot-app-config-v2
  labels:
    version: "2.0"
```

### 6. Don't Store Secrets in ConfigMaps
```yaml
# ❌ BAD - Don't do this
data:
  DATABASE_PASSWORD: "password123"
  API_KEY: "secret-key"

# ✅ GOOD - Use Secrets instead
# See secret.yaml
```

### 7. Set Resource Limits
```yaml
# In deployment.yaml
resources:
  limits:
    memory: ${MEMORY_LIMIT:-512Mi}  # From ConfigMap
  requests:
    memory: ${MEMORY_REQUEST:-256Mi}  # From ConfigMap
```

---

## Troubleshooting

### ConfigMap Not Found

```powershell
# Check if ConfigMap exists
kubectl get configmap springboot-app-config -n production

# Check namespace
kubectl get configmap --all-namespaces | Select-String "springboot"

# Create if missing
kubectl apply -f configmap.yaml
```

### Pods Not Picking Up Changes

```powershell
# ConfigMaps are not automatically reloaded
# You must restart pods

# Option 1: Restart deployment
kubectl rollout restart deployment springboot-app -n production

# Option 2: Delete pods (they'll be recreated)
kubectl delete pods -l app=springboot-app -n production

# Option 3: Use a tool like Reloader
# https://github.com/stakater/Reloader
```

### Check if ConfigMap is Mounted

```powershell
# Exec into pod
kubectl exec -it springboot-app-xxx -n production -- /bin/sh

# Check environment variables
env | grep SPRING

# Check mounted files (if using volume mount)
ls -la /etc/config
cat /etc/config/SPRING_PROFILES_ACTIVE
```

### View ConfigMap in Pod

```powershell
# Check environment variables in pod
kubectl exec springboot-app-xxx -n production -- env | Select-String "SPRING"

# Check specific value
kubectl exec springboot-app-xxx -n production -- printenv SPRING_PROFILES_ACTIVE
```

---

## Advanced Examples

### Multi-Line Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  application.properties: |
    server.port=8080
    spring.datasource.url=jdbc:postgresql://db:5432/myapp
    spring.jpa.hibernate.ddl-auto=update
    logging.level.root=INFO
  
  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
      </appender>
      <root level="info">
        <appender-ref ref="STDOUT" />
      </root>
    </configuration>
```

### Binary Data

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
binaryData:
  logo.png: <base64-encoded-image-data>
```

### Immutable ConfigMap (Kubernetes 1.21+)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
immutable: true  # Cannot be modified after creation
data:
  SPRING_PROFILES_ACTIVE: "production"
```

---

## Summary

**ConfigMap is like a settings file for your application in Kubernetes:**

✅ **Stores configuration separately from code**
✅ **Easy to update without rebuilding images**
✅ **Different configs for different environments**
✅ **Kubernetes-native way to manage configuration**
✅ **Can be shared across multiple pods/deployments**

**Your Project's ConfigMap Sets:**
1. Spring profile to "production"
2. Server port to 8080
3. Java memory limits (512MB max, 256MB initial)

**Key Takeaway:** ConfigMaps make your application flexible and easy to configure without touching the code or Docker image!

---

## Related Files

- `k8s/configmap.yaml` - Your ConfigMap definition
- `k8s/secret.yaml` - For sensitive data
- `k8s/deployment.yaml` - References ConfigMap
- `src/main/resources/application.yml` - Uses ConfigMap values

## References

- [Kubernetes ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Spring Boot External Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)
- [12-Factor App Config](https://12factor.net/config)
