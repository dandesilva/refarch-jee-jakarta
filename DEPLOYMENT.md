# Deployment Guide

Complete deployment instructions for Customer Order Services Jakarta EE application across different environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Container Deployment](#container-deployment)
- [Standalone WildFly](#standalone-wildfly)
- [Kubernetes/OpenShift](#kubernetesopenshift)
- [Production Considerations](#production-considerations)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

| Software | Minimum Version | Recommended | Purpose |
|----------|----------------|-------------|---------|
| Java JDK | 11 or 21 (LTS) | 21 LTS | Application runtime |
| Maven | 3.6 | 3.9.x | Build tool |
| Podman/Docker | Any | Latest | Containerization |
| PostgreSQL | 12 | 15 | Database |
| WildFly | 27 | 31.0.1 | Application server |

**Note:** This repository supports both Java 11 and Java 21. See [VERSION_MATRIX.md](VERSION_MATRIX.md) for version-specific guidance.

### System Requirements

**Minimum:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 10 GB free

**Recommended:**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 20 GB free

---

## Local Development

### Option 1: Maven + Standalone WildFly

**Step 1: Build the Application**

```bash
cd CustomerOrderServicesProject
mvn clean package
```

**Step 2: Setup PostgreSQL**

```bash
# Using Podman
podman run -d --name postgres-dev \
  -p 5432:5432 \
  -e POSTGRES_DB=ORDERDB \
  -e POSTGRES_USER=db2inst1 \
  -e POSTGRES_PASSWORD=db2inst1 \
  postgres:15

# Load schema
podman exec -i postgres-dev \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql
```

**Step 3: Configure WildFly**

Download and extract WildFly 31:
```bash
wget https://github.com/wildfly/wildfly/releases/download/31.0.1.Final/wildfly-31.0.1.Final.tar.gz
tar -xzf wildfly-31.0.1.Final.tar.gz
cd wildfly-31.0.1.Final
```

Download PostgreSQL JDBC driver:
```bash
mkdir -p modules/system/layers/base/org/postgresql/main
cd modules/system/layers/base/org/postgresql/main

wget https://jdbc.postgresql.org/download/postgresql-42.7.1.jar

cat > module.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<module xmlns="urn:jboss:module:1.9" name="org.postgresql">
    <resources>
        <resource-root path="postgresql-42.7.1.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
EOF
```

**Step 4: Start WildFly and Configure Datasource**

```bash
# Start WildFly
./bin/standalone.sh

# In another terminal, add datasource
./bin/jboss-cli.sh --connect

# Execute these commands in CLI:
/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=org.postgresql,driver-class-name=org.postgresql.Driver)

data-source add --name=OrderDS --jndi-name=java:/jdbc/orderds --driver-name=postgresql --connection-url=jdbc:postgresql://localhost:5432/ORDERDB --user-name=db2inst1 --password=db2inst1 --enabled=true --use-java-context=true --jta=true --validate-on-match=true --background-validation=false

exit
```

**Step 5: Deploy Application**

```bash
cp /path/to/CustomerOrderServicesApp/target/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear \
   deployments/
```

**Step 6: Verify Deployment**

```bash
# Check logs
tail -f standalone/log/server.log

# Test endpoint
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1
```

---

## Container Deployment

### Option 2: Podman/Docker

**Step 1: Create Container Network**

```bash
podman network create customerorder-net
```

**Step 2: Start PostgreSQL**

```bash
podman run -d --name postgres-orderdb \
  --network customerorder-net \
  -p 15432:5432 \
  -e POSTGRES_DB=ORDERDB \
  -e POSTGRES_USER=db2inst1 \
  -e POSTGRES_PASSWORD=db2inst1 \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15
```

**Step 3: Initialize Database**

```bash
# Wait for PostgreSQL to be ready
sleep 10

# Load schema
podman exec -i postgres-orderdb \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql
```

**Step 4: Build Application Container**

```bash
podman build -f Dockerfile.redhat -t customerorder-app:latest .
```

**Step 5: Run Application**

```bash
podman run -d --name customerorder-app \
  --network customerorder-net \
  -p 8080:8080 \
  -p 9990:9990 \
  customerorder-app:latest
```

**Step 6: Verify**

```bash
# Check logs
podman logs -f customerorder-app

# Test API
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category
```

### Using Docker Compose / Podman Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres-orderdb
    environment:
      POSTGRES_DB: ORDERDB
      POSTGRES_USER: db2inst1
      POSTGRES_PASSWORD: db2inst1
    ports:
      - "15432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./Common/createOrderDB_postgres.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - customerorder-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U db2inst1 -d ORDERDB"]
      interval: 10s
      timeout: 5s
      retries: 5

  wildfly:
    build:
      context: .
      dockerfile: Dockerfile.redhat
    container_name: customerorder-app
    ports:
      - "8080:8080"
      - "9990:9990"
    networks:
      - customerorder-net
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=ORDERDB
      - DB_USER=db2inst1
      - DB_PASSWORD=db2inst1

volumes:
  postgres-data:

networks:
  customerorder-net:
    driver: bridge
```

**Deploy:**
```bash
podman-compose up -d
# OR
docker-compose up -d
```

---

## Standalone WildFly

### Production WildFly Deployment

**Step 1: Install WildFly as a Service**

```bash
# Create wildfly user
sudo useradd -r -g wildfly -d /opt/wildfly -s /sbin/nologin wildfly

# Extract WildFly
sudo tar -xzf wildfly-31.0.1.Final.tar.gz -C /opt/
sudo ln -s /opt/wildfly-31.0.1.Final /opt/wildfly
sudo chown -R wildfly:wildfly /opt/wildfly/
```

**Step 2: Configure as systemd service**

Create `/etc/systemd/system/wildfly.service`:

```ini
[Unit]
Description=WildFly Application Server
After=network.target postgresql.service

[Service]
Type=notify
User=wildfly
Group=wildfly
# For Java 11: /usr/lib/jvm/java-11-openjdk
# For Java 21: /usr/lib/jvm/java-21-openjdk
Environment="JAVA_HOME=/usr/lib/jvm/java-21-openjdk"
Environment="WILDFLY_HOME=/opt/wildfly"
Environment="JAVA_OPTS=-Xms512m -Xmx2048m"
ExecStart=/opt/wildfly/bin/standalone.sh -b 0.0.0.0 -bmanagement 0.0.0.0
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Step 3: Enable and Start**

```bash
sudo systemctl daemon-reload
sudo systemctl enable wildfly
sudo systemctl start wildfly
sudo systemctl status wildfly
```

**Step 4: Configure Datasource**

```bash
sudo -u wildfly /opt/wildfly/bin/jboss-cli.sh --connect << 'EOF'
/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=org.postgresql,driver-class-name=org.postgresql.Driver)
data-source add --name=OrderDS --jndi-name=java:/jdbc/orderds --driver-name=postgresql --connection-url=jdbc:postgresql://localhost:5432/ORDERDB --user-name=db2inst1 --password=db2inst1 --enabled=true
reload
EOF
```

**Step 5: Deploy Application**

```bash
sudo cp CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear \
  /opt/wildfly/standalone/deployments/
sudo chown wildfly:wildfly \
  /opt/wildfly/standalone/deployments/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear
```

---

## Kubernetes/OpenShift

### Kubernetes Deployment

**Step 1: Create Namespace**

```bash
kubectl create namespace customerorder
kubectl config set-context --current --namespace=customerorder
```

**Step 2: Create PostgreSQL**

Create `postgres-deployment.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  username: db2inst1
  password: db2inst1
  database: ORDERDB
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

**Step 3: Create Application Deployment**

Create `app-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customerorder-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: customerorder
  template:
    metadata:
      labels:
        app: customerorder
    spec:
      containers:
      - name: wildfly
        image: customerorder-app:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9990
          name: admin
        livenessProbe:
          httpGet:
            path: /CustomerOrderServicesWeb/jaxrs/Category
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /CustomerOrderServicesWeb/jaxrs/Category
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
---
apiVersion: v1
kind: Service
metadata:
  name: customerorder-service
spec:
  selector:
    app: customerorder
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: admin
    port: 9990
    targetPort: 9990
  type: LoadBalancer
```

**Step 4: Deploy**

```bash
kubectl apply -f postgres-deployment.yaml
kubectl apply -f app-deployment.yaml
```

**Step 5: Initialize Database**

```bash
# Get postgres pod name
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Load schema
kubectl exec -i $POSTGRES_POD -- \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql
```

**Step 6: Verify**

```bash
# Check pods
kubectl get pods

# Check logs
kubectl logs -l app=customerorder

# Get service URL
kubectl get service customerorder-service

# Test
curl http://<EXTERNAL-IP>/CustomerOrderServicesWeb/jaxrs/Product/1
```

---

## Production Considerations

### Security

**1. Enable HTTPS**

For WildFly, generate certificate and configure:

```bash
# Generate keystore
keytool -genkeypair -alias wildfly -keyalg RSA -keysize 2048 \
  -validity 365 -keystore wildfly.keystore -storepass changeit \
  -dname "CN=yourserver.com"

# Configure in WildFly CLI
/core-service=management/security-realm=ApplicationRealm/server-identity=ssl:add(keystore-path=wildfly.keystore, keystore-password=changeit)

/subsystem=undertow/server=default-server/https-listener=https:add(socket-binding=https, security-realm=ApplicationRealm)
```

**2. Configure Authentication**

Replace `@PermitAll` with proper security:

```java
@Stateless
@RolesAllowed("CustomerRole")
public class CustomerOrderServicesImpl implements CustomerOrderServices {
    // ...
}
```

Configure security domain in WildFly.

**3. Secure Admin Console**

```bash
# Change admin password
/opt/wildfly/bin/add-user.sh

# Restrict admin access
/core-service=management/management-interface=http-interface:write-attribute(name=allowed-origins,value=["https://admin.yourcompany.com"])
```

### Performance Tuning

**1. JVM Options**

```bash
# Set in standalone.conf
JAVA_OPTS="$JAVA_OPTS -Xms2g -Xmx4g"
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC"
JAVA_OPTS="$JAVA_OPTS -XX:MaxGCPauseMillis=200"
```

**2. Connection Pool**

```bash
# Optimize datasource
/subsystem=datasources/data-source=OrderDS:write-attribute(name=min-pool-size,value=10)
/subsystem=datasources/data-source=OrderDS:write-attribute(name=max-pool-size,value=50)
/subsystem=datasources/data-source=OrderDS:write-attribute(name=pool-prefill,value=true)
```

**3. EJB Thread Pool**

```bash
/subsystem=ejb3/thread-pool=default:write-attribute(name=max-threads,value=100)
```

### Monitoring

**1. Enable Metrics**

```bash
/subsystem=microprofile-metrics-smallrye:write-attribute(name=exposed-subsystems,value=["*"])
```

**2. Access Metrics**

```bash
curl http://localhost:9990/metrics
```

**3. Configure Logging**

```bash
/subsystem=logging/logger=org.pwte.example:add(level=DEBUG)
/subsystem=logging/logger=org.hibernate:add(level=INFO)
```

### Backup Strategy

**1. Database Backups**

```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
podman exec postgres-orderdb pg_dump -U db2inst1 ORDERDB > \
  /backups/orderdb_$DATE.sql

# Keep only last 7 days
find /backups -name "orderdb_*.sql" -mtime +7 -delete
```

**2. Application Backups**

- Keep all EAR files in artifact repository
- Version tag all deployments
- Document configuration changes

### High Availability

**1. Multiple WildFly Instances**

```bash
# Start multiple instances behind load balancer
./standalone.sh -Djboss.node.name=node1 -Djboss.socket.binding.port-offset=0
./standalone.sh -Djboss.node.name=node2 -Djboss.socket.binding.port-offset=100
```

**2. Database Replication**

Configure PostgreSQL streaming replication for HA.

**3. Load Balancer**

Use nginx, HAProxy, or cloud load balancers.

---

## Troubleshooting

### Application Won't Start

**Check WildFly logs:**
```bash
tail -f standalone/log/server.log
# OR for containers
podman logs -f customerorder-app
```

**Common issues:**
- Database not accessible
- JNDI name incorrect
- Missing dependencies
- Port conflicts

### Database Connection Errors

**Test PostgreSQL connectivity:**
```bash
psql -h localhost -p 15432 -U db2inst1 -d ORDERDB
```

**Check datasource in WildFly:**
```bash
/subsystem=datasources/data-source=OrderDS:test-connection-in-pool
```

### REST Endpoints Return 404

**Verify deployment:**
```bash
# Check deployed applications
ls standalone/deployments/

# Check for .failed or .undeployed markers
```

**Check context root:**
- Should be `/CustomerOrderServicesWeb/jaxrs/*`
- Verify in browser: http://localhost:8080/CustomerOrderServicesWeb/

### Performance Issues

**Check connection pool:**
```bash
/subsystem=datasources/data-source=OrderDS/statistics=pool:read-resource(include-runtime=true)
```

**Check thread pool:**
```bash
/subsystem=io/worker=default:read-resource(include-runtime=true)
```

### Memory Leaks

**Enable heap dumps:**
```bash
JAVA_OPTS="$JAVA_OPTS -XX:+HeapDumpOnOutOfMemoryError"
JAVA_OPTS="$JAVA_OPTS -XX:HeapDumpPath=/opt/wildfly/heapdumps"
```

**Analyze with:**
- Eclipse MAT
- VisualVM
- JProfiler

---

## Maintenance

### Updating Application

```bash
# 1. Build new version
mvn clean package

# 2. Backup current deployment
cp standalone/deployments/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear \
   backups/CustomerOrderServicesApp-$(date +%Y%m%d).ear

# 3. Stop app (creates .undeployed marker)
touch standalone/deployments/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear.dodeploy.undeployed

# 4. Replace EAR
cp CustomerOrderServicesApp/target/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear \
   standalone/deployments/

# 5. Redeploy
touch standalone/deployments/CustomerOrderServicesApp-0.1.0-SNAPSHOT.ear.dodeploy
```

### Updating WildFly

1. Test new version in dev/staging
2. Review release notes for breaking changes
3. Backup configuration
4. Perform rolling update in production

### Database Migrations

Use Flyway or Liquibase for schema versioning:

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
    <version>9.22.0</version>
</dependency>
```

---

## Quick Reference Commands

### Build
```bash
mvn clean package
```

### Local Run
```bash
# Database
podman run -d --name postgres-orderdb -p 15432:5432 \
  -e POSTGRES_DB=ORDERDB -e POSTGRES_USER=db2inst1 -e POSTGRES_PASSWORD=db2inst1 postgres:15

# Application
podman build -f Dockerfile.redhat -t customerorder-app .
podman run -d --name customerorder-app -p 8080:8080 customerorder-app
```

### Test
```bash
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category
```

### Logs
```bash
# Container
podman logs -f customerorder-app

# Standalone
tail -f $WILDFLY_HOME/standalone/log/server.log
```

### Stop/Cleanup
```bash
podman stop customerorder-app postgres-orderdb
podman rm customerorder-app postgres-orderdb
podman network rm customerorder-net
```

---

**Last Updated:** April 9, 2026  
**Java Versions:** 11 (Conservative) | 21 (Recommended) - see [VERSION_MATRIX.md](VERSION_MATRIX.md)  
**Tested Environments:** RHEL 9, Ubuntu 22.04, macOS 14 (Sonoma)  
**Container Runtimes:** Podman 4.9, Docker 25.x
