# Kubernetes Refactoring - 수정 사항 요약

## 📋 프로젝트 구조

```
spring-petclinic-microservices/
├── spring-petclinic-admin-server/
│   ├── pom.xml (수정 ✅)
│   └── src/main/resources/
│       └── application.yml (수정 ✅)
├── spring-petclinic-api-gateway/
│   ├── pom.xml (수정 ✅)
│   ├── src/main/resources/
│   │   └── application.yml (수정 ✅)
│   └── Dockerfile (신규 ✨)
├── spring-petclinic-config-server/
│   ├── pom.xml (수정 ✅)
│   └── src/main/resources/
│       └── application.yml (수정 ✅)
├── spring-petclinic-customers-service/
│   ├── pom.xml (수정 ✅)
│   ├── src/main/resources/
│   │   └── application.yml (수정 ✅)
│   └── Dockerfile (신규 ✨)
├── spring-petclinic-discovery-server/
│   ├── pom.xml (수정 ✅)
│   └── src/main/resources/
│       └── application.yml (수정 ✅)
├── spring-petclinic-genai-service/
│   ├── pom.xml (수정 ✅)
│   ├── src/main/resources/
│   │   └── application.yml (수정 ✅)
│   └── Dockerfile (신규 ✨)
├── spring-petclinic-vets-service/
│   ├── pom.xml (수정 ✅)
│   ├── src/main/resources/
│   │   └── application.yml (수정 ✅)
│   └── Dockerfile (신규 ✨)
├── spring-petclinic-visits-service/
│   ├── pom.xml (수정 ✅)
│   ├── src/main/resources/
│   │   └── application.yml (수정 ✅)
│   └── Dockerfile (신규 ✨)
└── KUBERNETES_REFACTORING_GUIDE.md (신규 ✨)
```

## 📦 1단계: pom.xml 수정

### 제거된 의존성
- ❌ `spring-cloud-starter-netflix-eureka-client` (모든 마이크로서비스)
- ❌ `spring-cloud-starter-netflix-eureka-server` (Discovery Server)
- ❌ `spring-cloud-starter-config` (모든 마이크로서비스)
- ❌ `spring-cloud-config-server` (Config Server)

### 추가/유지된 의존성
- ✅ `spring-boot-starter-actuator` (모든 마이크로서비스 - 이미 있거나 추가)
- ✅ `micrometer-registry-prometheus` (모든 마이크로서비스)
- ✅ `spring-cloud-starter-gateway` (API Gateway만 유지)

**수정된 파일:**
1. `spring-petclinic-customers-service/pom.xml`
2. `spring-petclinic-vets-service/pom.xml`
3. `spring-petclinic-visits-service/pom.xml`
4. `spring-petclinic-api-gateway/pom.xml`
5. `spring-petclinic-admin-server/pom.xml`
6. `spring-petclinic-genai-service/pom.xml`
7. `spring-petclinic-discovery-server/pom.xml`
8. `spring-petclinic-config-server/pom.xml`

## ⚙️ 2단계: application.yml 수정

### 공통 변경사항 (모든 서비스)

#### 제거된 설정
```yaml
# ❌ 제거됨
spring:
  config:
    import: optional:configserver:${CONFIG_SERVER_URL:http://localhost:8888/}

---
spring:
  config:
    activate:
      on-profile: docker
    import: configserver:http://config-server:8888
```

#### 추가된 설정

**데이터베이스 (MySQL 외부화):**
```yaml
# ✅ 추가됨
spring:
  datasource:
    url: jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:petclinic}
    username: ${DB_USER:root}
    password: ${DB_PASS:root}
    driver-class-name: com.mysql.cj.jdbc.Driver
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
```

**모니터링 (Actuator & Prometheus):**
```yaml
# ✅ 추가됨
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

### API Gateway 특별 변경사항

#### Eureka 로드밸런싱 → K8s DNS
```yaml
# ❌ 기존
routes:
  - id: customers-service
    uri: lb://customers-service    # Eureka 로드밸런싱

# ✅ 변경됨
routes:
  - id: customers-service
    uri: http://customers-service:8080   # K8s DNS
```

**모든 라우트 업데이트:**
- `lb://vets-service` → `http://vets-service:8080`
- `lb://visits-service` → `http://visits-service:8080`
- `lb://customers-service` → `http://customers-service:8080`
- `lb://genai-service` → `http://genai-service:8080`

**수정된 파일:**
1. `spring-petclinic-customers-service/src/main/resources/application.yml`
2. `spring-petclinic-vets-service/src/main/resources/application.yml`
3. `spring-petclinic-visits-service/src/main/resources/application.yml`
4. `spring-petclinic-api-gateway/src/main/resources/application.yml`
5. `spring-petclinic-admin-server/src/main/resources/application.yml`
6. `spring-petclinic-genai-service/src/main/resources/application.yml`
7. `spring-petclinic-discovery-server/src/main/resources/application.yml`
8. `spring-petclinic-config-server/src/main/resources/application.yml`

## 🐳 3단계: Dockerfile 생성

### Multi-Stage Build 구조

**Stage 1 - 빌드:**
- Base Image: `maven:3.8-eclipse-temurin-17`
- Maven 빌드 (테스트 스킵)
- JAR 파일 생성

**Stage 2 - 런타임:**
- Base Image: `eclipse-temurin:17-jre-alpine`
- 경량 알파인 기반 JRE
- 비root 사용자 생성 (spring:spring)
- 헬스체크 활성화
- 포트 8080 노출

### Dockerfile 특징

```dockerfile
✅ 다중 스테이지 빌드 (최소 이미지 크기)
✅ 비root 사용자 실행 (보안)
✅ Spring Actuator 헬스체크
✅ 포트 8080 노출
✅ JMX 원격 디버깅 지원
```

**생성된 Dockerfile:**
1. `spring-petclinic-customers-service/Dockerfile` ✨
2. `spring-petclinic-vets-service/Dockerfile` ✨
3. `spring-petclinic-visits-service/Dockerfile` ✨
4. `spring-petclinic-api-gateway/Dockerfile` ✨
5. `spring-petclinic-genai-service/Dockerfile` ✨

## 🔧 4단계: 환경 변수 (K8s 배포용)

### 데이터베이스 설정
```bash
DB_HOST=mysql-service          # K8s 클러스터 내 서비스명
DB_PORT=3306                   # MySQL 포트
DB_NAME=petclinic              # 데이터베이스명
DB_USER=petclinic              # DB 사용자명
DB_PASS=<K8s Secret>           # DB 패스워드 (Secret으로 관리)
```

### GenAI 서비스 설정
```bash
AZURE_OPENAI_KEY=<key>         # Azure OpenAI API 키
AZURE_OPENAI_ENDPOINT=<url>    # Azure OpenAI 엔드포인트
OPENAI_API_KEY=<key>           # OpenAI API 키 (선택사항)
```

## ✅ 검증 사항

### 의존성 제거 확인
```bash
grep -r "spring-cloud-starter-netflix-eureka" . --include="*.xml"
# ❌ 결과: 주석 처리만 남음 (실제 의존성 제거됨)

grep -r "spring-cloud-starter-config" . --include="*.xml"
# ❌ 결과: 주석 처리만 남음 (실제 의존성 제거됨)
```

### 환경변수 확인
```bash
grep -r "DB_HOST\|DB_PORT\|DB_NAME" . --include="*.yml"
# ✅ 결과: 모든 데이터 서비스에서 확인됨
```

### K8s DNS 설정 확인
```bash
grep -r "http://.*-service:8080" . --include="*.yml"
# ✅ 결과: API Gateway 라우팅 규칙에서 확인됨
```

### Actuator/Prometheus 확인
```bash
grep -r "management:" . --include="*.yml" | grep -c "endpoints"
# ✅ 결과: 모든 마이크로서비스에서 활성화됨
```

## 📊 아키텍처 변경

| 컴포넌트 | 기존 (Spring Cloud) | 변경됨 (Kubernetes) |
|---------|-----------------|----------------|
| 서비스 발견 | Eureka Server | K8s DNS |
| 설정 관리 | Config Server | ConfigMaps/Secrets |
| 로드밸런싱 | Eureka Client + Spring | K8s Service |
| 서킷 브레이커 | Spring Cloud Netflix | Spring + Istio |
| 서비스 메시 | 없음 | Istio (선택사항) |
| 모니터링 | Prometheus/Grafana | Prometheus/Grafana |
| DB 설정 | Spring Config Server | 환경변수 |

## 📝 빌드 및 배포 명령어

### 빌드 검증
```bash
./mvnw clean package -DskipTests
```

### Docker 이미지 빌드
```bash
# Customers Service
docker build -f spring-petclinic-customers-service/Dockerfile \
  -t petclinic/customers-service:1.0 .

# Vets Service
docker build -f spring-petclinic-vets-service/Dockerfile \
  -t petclinic/vets-service:1.0 .

# Visits Service
docker build -f spring-petclinic-visits-service/Dockerfile \
  -t petclinic/visits-service:1.0 .

# API Gateway
docker build -f spring-petclinic-api-gateway/Dockerfile \
  -t petclinic/api-gateway:1.0 .

# GenAI Service
docker build -f spring-petclinic-genai-service/Dockerfile \
  -t petclinic/genai-service:1.0 .
```

### Kubernetes 배포 (예시)
```bash
# ConfigMap 생성
kubectl create configmap petclinic-config \
  --from-literal=DB_HOST=mysql-service \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_NAME=petclinic

# Secret 생성
kubectl create secret generic petclinic-secrets \
  --from-literal=DB_USER=petclinic \
  --from-literal=DB_PASS=secure_password

# 서비스 배포
kubectl apply -f kubernetes/
```

## 🔐 보안 권장사항

1. **비root 사용자:** 모든 컨테이너는 `spring:spring` 사용자로 실행
2. **Secrets 관리:** DB 패스워드는 K8s Secrets으로 관리
3. **네트워크 정책:** 서비스 간 통신 제한 설정
4. **RBAC:** 서비스 계정별 권한 설정
5. **이미지 보안:** 프라이빗 레지스트리에 이미지 저장

## 🎯 다음 단계

1. K8s Deployment 매니페스트 작성
2. K8s Service 매니페스트 작성
3. K8s ConfigMap/Secret 매니페스트 작성
4. MySQL 데이터베이스 설정
5. Prometheus 스크레이프 설정
6. Istio VirtualService/DestinationRule 설정 (선택사항)
7. EKS 클러스터에 배포 및 테스트
8. 본프로덕션 환경 배포

## 📞 지원 정보

- 모든 수정사항은 비즈니스 로직에 영향을 주지 않습니다
- 프로젝트는 여전히 로컬 개발 환경에서 실행 가능합니다
- 추가 문의는 `KUBERNETES_REFACTORING_GUIDE.md` 참고
