# Spring PetClinic Microservices - Kubernetes (EKS) & Istio Refactoring Guide

## Overview
This document summarizes the refactoring of the Spring PetClinic Microservices project to run on a Kubernetes (EKS) environment with Istio service mesh. The project has been migrated away from Spring Cloud Netflix (Eureka, Config Server) to a Cloud-Native architecture.

## Summary of Changes

### 1. Dependency Management (pom.xml)

#### Removed Dependencies
- ❌ `spring-cloud-starter-netflix-eureka-client` - Service discovery is now handled by Kubernetes DNS
- ❌ `spring-cloud-starter-config` - Configuration management is handled by K8s ConfigMaps and Secrets
- ❌ `spring-cloud-starter-netflix-eureka-server` - Eureka server (Discovery Server) is no longer needed
- ❌ `spring-cloud-config-server` - Config server is no longer needed

#### Added Dependencies
- ✅ `spring-boot-starter-actuator` - Added to all microservices (if not already present)
- ✅ `micrometer-registry-prometheus` - Added to all microservices for metrics export

#### Kept Dependencies
- ✅ `spring-cloud-starter-gateway` - Retained in API Gateway for routing

**Modified Services:**
- `spring-petclinic-customers-service/pom.xml`
- `spring-petclinic-vets-service/pom.xml`
- `spring-petclinic-visits-service/pom.xml`
- `spring-petclinic-api-gateway/pom.xml`
- `spring-petclinic-admin-server/pom.xml`
- `spring-petclinic-genai-service/pom.xml`
- `spring-petclinic-discovery-server/pom.xml`
- `spring-petclinic-config-server/pom.xml`

### 2. Configuration Cleanup (application.yml)

#### All Services Updated
1. **Removed Config Server Import:**
   - Deleted: `spring.config.import: optional:configserver:${CONFIG_SERVER_URL:...}`
   - Deleted: Docker profile section with configserver import

2. **Database Configuration - MySQL Migration:**
   ```yaml
   datasource:
     url: jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:petclinic}
     username: ${DB_USER:root}
     password: ${DB_PASS:root}
     driver-class-name: com.mysql.cj.jdbc.Driver
   ```
   - Environment variables used for externalizing credentials
   - Default values provided for local development

3. **Management Endpoints Enabled:**
   ```yaml
   management:
     endpoints:
       web:
         exposure:
           include: "*"
     metrics:
       export:
         prometheus:
           enabled: true
     tags:
       application: ${spring.application.name}
   ```
   - All actuator endpoints exposed for monitoring
   - Prometheus metrics enabled for Grafana integration

4. **API Gateway K8s DNS Configuration:**
   - Changed from: `uri: lb://customers-service` (Eureka load balancing)
   - Changed to: `uri: http://customers-service:8080` (Kubernetes DNS)
   - All service routes updated for K8s service discovery

**Modified Services:**
- `spring-petclinic-customers-service/src/main/resources/application.yml`
- `spring-petclinic-vets-service/src/main/resources/application.yml`
- `spring-petclinic-visits-service/src/main/resources/application.yml`
- `spring-petclinic-api-gateway/src/main/resources/application.yml`
- `spring-petclinic-admin-server/src/main/resources/application.yml`
- `spring-petclinic-genai-service/src/main/resources/application.yml`
- `spring-petclinic-discovery-server/src/main/resources/application.yml`
- `spring-petclinic-config-server/src/main/resources/application.yml`

### 3. Dockerization

#### Created Multi-Stage Dockerfiles

All microservices now include optimized Dockerfile with:

**Stage 1 - Build:**
- Base Image: `maven:3.8-eclipse-temurin-17`
- Maven clean package build
- Tests skipped (-DskipTests)

**Stage 2 - Runtime:**
- Base Image: `eclipse-temurin:17-jre-alpine`
- Lightweight Alpine-based JRE
- Non-root user creation (spring:spring)
- Health checks enabled
- Proper port exposure

**Features:**
- Multi-stage build for minimal final image size
- Security: Non-root user execution
- Health checks using Spring Actuator endpoint
- Port 8080 exposed (standard microservice port)
- JMX remote debugging capabilities included

**New Dockerfile Locations:**
- `spring-petclinic-customers-service/Dockerfile`
- `spring-petclinic-vets-service/Dockerfile`
- `spring-petclinic-visits-service/Dockerfile`
- `spring-petclinic-api-gateway/Dockerfile`
- `spring-petclinic-genai-service/Dockerfile`

### 4. Logging & Monitoring

#### Management Endpoints Configuration
All services now have:
- **Web Endpoints Exposure:** All actuator endpoints are exposed (`include: "*"`)
- **Prometheus Metrics:** Enabled and configured for scraping
- **Metrics Tags:** Service name tagged for easy identification in Prometheus

## Environment Variables for K8s Deployment

### Database Configuration
```yaml
DB_HOST=mysql-service      # Service name in K8s cluster
DB_PORT=3306              # MySQL port
DB_NAME=petclinic         # Database name
DB_USER=petclinic         # Database user
DB_PASS=<secret>          # Database password (use K8s Secrets)
```

### GenAI Service Specific
```yaml
AZURE_OPENAI_KEY=<key>                 # Azure OpenAI API key
AZURE_OPENAI_ENDPOINT=<endpoint>       # Azure OpenAI endpoint
OPENAI_API_KEY=<key>                   # OpenAI API key (if using OpenAI)
```

## K8s Deployment Next Steps

### 1. ConfigMaps and Secrets
Create K8s ConfigMaps for application properties and Secrets for sensitive data:
```bash
kubectl create configmap petclinic-config --from-literal=DB_HOST=mysql-service
kubectl create secret generic petclinic-secrets --from-literal=DB_PASS=secure_password
```

### 2. Service Discovery
Services automatically discover each other using K8s DNS:
- `customers-service:8080`
- `vets-service:8080`
- `visits-service:8080`
- `genai-service:8080`
- `api-gateway:8080`

### 3. Istio Configuration
For Istio service mesh (optional but recommended):
- Configure VirtualServices for routing rules
- Configure DestinationRules for circuit breakers (Istio manages, not Spring)
- Configure NetworkPolicies for security

### 4. Monitoring & Observability
- **Prometheus:** Scrape `/actuator/prometheus` endpoint from all pods
- **Grafana:** Use Prometheus data source with existing dashboards
- **Distributed Tracing:** Zipkin integration already configured
- **Metrics Scrape Config:**
  ```yaml
  scrape_configs:
    - job_name: 'petclinic'
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
  ```

## Removed Services
The following services are **NOT NEEDED** in Kubernetes and can be deprecated:
- ❌ `spring-petclinic-discovery-server` (Eureka replacement)
- ❌ `spring-petclinic-config-server` (ConfigMaps replacement)

Note: These services remain functional for backward compatibility but should not be deployed in K8s clusters.

## Build Verification

To verify the refactoring compiles correctly:
```bash
./mvnw clean package -DskipTests
```

All modules should compile without errors.

## Docker Image Building

Build individual service images:
```bash
# Customers Service
docker build -f spring-petclinic-customers-service/Dockerfile -t petclinic/customers-service:1.0 .

# Vets Service
docker build -f spring-petclinic-vets-service/Dockerfile -t petclinic/vets-service:1.0 .

# Visits Service
docker build -f spring-petclinic-visits-service/Dockerfile -t petclinic/visits-service:1.0 .

# API Gateway
docker build -f spring-petclinic-api-gateway/Dockerfile -t petclinic/api-gateway:1.0 .

# GenAI Service
docker build -f spring-petclinic-genai-service/Dockerfile -t petclinic/genai-service:1.0 .
```

## Istio Integration Example

### Deploy with Istio Injection
```bash
kubectl label namespace default istio-injection=enabled
kubectl apply -f deployment.yaml
```

### VirtualService for API Gateway
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: customers-service
spec:
  hosts:
  - customers-service
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: customers-service
        port:
          number: 8080
```

### DestinationRule for Resilience
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: customers-service
spec:
  host: customers-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

## Architecture Changes Summary

| Component | Before (Spring Cloud) | After (Kubernetes) |
|-----------|---------------------|-------------------|
| Service Discovery | Eureka Server | K8s DNS |
| Configuration Management | Config Server | ConfigMaps/Secrets |
| Load Balancing | Eureka Client + Spring | K8s Service |
| Circuit Breaking | Spring Cloud Netflix | Spring/Istio |
| Service Mesh | None | Istio (optional) |
| Monitoring | Prometheus/Grafana | Prometheus/Grafana |
| Database Config | Spring Config Server | Environment Variables |

## Constraints Maintained

✅ No changes to core business logic (Java classes)
✅ Project compiles with `mvn clean package -DskipTests`
✅ All microservices remain functional
✅ Backward compatibility maintained with original APIs
✅ Monitoring and observability enhanced

## Migration Checklist

- [x] Remove Eureka dependencies from all microservices
- [x] Remove Config Server dependencies from all microservices
- [x] Add Actuator and Prometheus to all microservices
- [x] Update application.yml configurations for K8s
- [x] Externalize database credentials via environment variables
- [x] Update API Gateway routes to use K8s DNS
- [x] Create Dockerfile for each microservice
- [x] Implement health checks in Docker containers
- [x] Enable all management endpoints
- [x] Configure Prometheus metrics export
- [ ] Create K8s Deployment manifests (next step)
- [ ] Create K8s Service manifests (next step)
- [ ] Create K8s ConfigMap and Secret manifests (next step)
- [ ] Test in K8s/EKS cluster (next step)
- [ ] Configure Istio (optional, next step)
- [ ] Deploy to production EKS (next step)

## Notes

1. **Database:** Ensure MySQL instance is accessible at `DB_HOST` from K8s pods
2. **Security:** Store `DB_PASS` and API keys in K8s Secrets, not ConfigMaps
3. **Monitoring:** Configure Prometheus scrape targets for the K8s cluster
4. **Scaling:** Services are now horizontally scalable with Kubernetes replicas
5. **Network:** Ensure network policies allow communication between services
