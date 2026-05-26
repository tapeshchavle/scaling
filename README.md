# 🍕 Food Application - Scalable Microservice Architecture

A production-ready, high-performance food delivery application built with **Java Spring Boot** microservices, designed to scale from thousands to **10 million+ users**. Features read/write splitting with MySQL replication, Redis caching with Sentinel-based failover, and Nginx load balancing.

---

## 📐 Architecture Overview

```
                         ┌─────────────────────────────┐
                         │        Azure CDN            │
                         │   (Static Assets Cache)     │
                         └─────────────┬───────────────┘
                                       │
                                       ▼
                         ┌─────────────────────────────┐
                         │     Nginx API Gateway       │
                         │       (Port 80)             │
                         │  ┌─────────┬──────────┐     │
                         │  │ /api/*  │ /notify/*│     │
                         │  └────┬────┴────┬─────┘     │
                         └───────┼─────────┼───────────┘
                                 │         │
                    ┌────────────┘         └────────────┐
                    ▼                                   ▼
        ┌───────────────────┐               ┌───────────────────┐
        │   Food Core (x2)  │               │ Notification (x2) │
        │    Port 8081      │               │    Port 8082      │
        │  Spring Boot 3.x  │               │  Spring Boot 3.x  │
        └───────┬───────────┘               └───────┬───────────┘
                │                                   │
        ┌───────┴───────┐                           │
        ▼               ▼                           ▼
  ┌──────────┐   ┌──────────┐              ┌──────────────────┐
  │  MySQL   │   │  MySQL   │              │  Redis Cluster   │
  │  Master  │   │  Slave   │              │                  │
  │  (Write) │──▶│  (Read)  │              │  Master ──▶ Slave│
  │  :3306   │   │  :3307   │              │  :6379    :6380  │
  └──────────┘   └──────────┘              │                  │
                                           │  Sentinel :26379 │
                                           └──────────────────┘
```

---

## 🛠 Tech Stack

| Layer              | Technology                  | Purpose                                |
|--------------------|-----------------------------|----------------------------------------|
| **Language**       | Java 21                     | Core application language              |
| **Framework**      | Spring Boot 3.x             | Microservice framework                 |
| **API Gateway**    | Nginx                       | Load balancing & reverse proxy         |
| **Database**       | MySQL 8.0 (Master-Slave)    | Persistent data with read replicas     |
| **Cache**          | Redis 7 (Master-Slave)      | High-speed caching & pub/sub           |
| **HA Monitor**     | Redis Sentinel              | Automatic failover for Redis           |
| **Containers**     | Docker & Docker Compose     | Containerization & orchestration       |
| **Build Tool**     | Maven 3.9+                  | Dependency management & builds         |
| **CI/CD**          | GitHub Actions              | Automated testing & deployment         |
| **Cloud**          | Microsoft Azure             | Production hosting                     |
| **CDN**            | Azure CDN                   | Static asset delivery & edge caching   |

---

## ✅ Prerequisites

Before you begin, ensure you have the following installed:

| Tool              | Minimum Version | Check Command             |
|-------------------|-----------------|---------------------------|
| **Java JDK**      | 21              | `java --version`          |
| **Maven**         | 3.9+            | `mvn --version`           |
| **Docker**        | 24.0+           | `docker --version`        |
| **Docker Compose**| 2.20+           | `docker compose version`  |

---

## 🚀 Quick Start

### 1. Clone and configure

```bash
git clone <repository-url>
cd scaling
cp .env.example .env
```

Edit `.env` with your preferred credentials:

```env
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=food_db
MYSQL_USER=food_user
MYSQL_PASSWORD=changeme
REDIS_PASSWORD=changeme
```

### 2. Build and start all services

```bash
docker compose up --build -d
```

### 3. Verify services are healthy

```bash
# Check all container statuses
docker compose ps

# Verify health endpoints
curl http://localhost/api/actuator/health        # Food Core (via Nginx)
curl http://localhost/notify/actuator/health      # Notification Service (via Nginx)
```

### 4. Stop all services

```bash
docker compose down
```

To also remove all data volumes:

```bash
docker compose down -v
```

---

## 🌐 Service URLs

| Service                | URL                                          | Description                    |
|------------------------|----------------------------------------------|--------------------------------|
| **Nginx Gateway**      | `http://localhost`                            | API Gateway entrypoint         |
| **Food Core API**      | `http://localhost/api/*`                      | Food CRUD & ordering APIs      |
| **Food Core Health**   | `http://localhost/api/actuator/health`        | Food Core health check         |
| **Notification API**   | `http://localhost/notify/*`                   | Notification endpoints         |
| **Notification Health**| `http://localhost/notify/actuator/health`     | Notification health check      |
| **MySQL Master**       | `localhost:3306`                              | Primary database (read/write)  |
| **MySQL Slave**        | `localhost:3307`                              | Read replica (read-only)       |
| **Redis Master**       | `localhost:6379` *(dev only)*                 | Cache primary                  |
| **Redis Slave**        | `localhost:6380`                              | Cache replica                  |

---

## 🔧 Development Setup

For local development with debug ports and single replicas:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build -d
```

### Development overrides include:

- **Single replicas** for `food-core` and `notification-service`
- **Increased resources** (768M memory, 1.0 CPU)
- **Debug ports exposed**:
  - `food-core`: `localhost:5005`
  - `notification-service`: `localhost:5006`
- **Direct access** to MySQL (`3306`) and Redis (`6379`)

### Attaching a debugger

In your IDE (IntelliJ IDEA / VS Code), create a **Remote JVM Debug** configuration:

| Service                | Host        | Port  |
|------------------------|-------------|-------|
| **food-core**          | `localhost` | 5005  |
| **notification-service** | `localhost` | 5006  |

---

## 📈 Scaling

Scale individual services based on demand:

```bash
# Scale food-core to 4 instances and notification-service to 3
docker compose up --scale food-core=4 --scale notification-service=3 -d
```

Nginx automatically load-balances across all replicas using round-robin.

### Recommended scaling tiers:

| Users       | food-core | notification-service | MySQL Slaves | Redis Slaves |
|-------------|-----------|----------------------|--------------|--------------|
| < 10K       | 2         | 2                    | 1            | 1            |
| 10K - 100K  | 4         | 3                    | 2            | 2            |
| 100K - 1M   | 8         | 6                    | 4            | 3            |
| 1M - 10M    | 16+       | 10+                  | 8+           | 5+           |

> **Note**: For 1M+ users, consider migrating to Kubernetes for advanced orchestration, auto-scaling, and service mesh capabilities.

---

## 📁 Project Structure

```
scaling/
├── docker-compose.yml              # Production compose configuration
├── docker-compose.dev.yml          # Development overrides
├── .env.example                    # Environment variable template
├── .github/
│   └── workflows/
│       └── ci.yml                  # GitHub Actions CI/CD pipeline
│
├── gateway/
│   ├── Dockerfile                  # Nginx container build
│   └── nginx.conf                  # Nginx routing & load balancing config
│
├── services/
│   ├── food-core/
│   │   ├── Dockerfile              # Food Core container build
│   │   ├── pom.xml                 # Maven dependencies
│   │   └── src/
│   │       ├── main/
│   │       │   ├── java/...        # Application source code
│   │       │   └── resources/
│   │       │       ├── application.yml
│   │       │       └── application-docker.yml
│   │       └── test/               # Unit & integration tests
│   │
│   └── notification-service/
│       ├── Dockerfile              # Notification container build
│       ├── pom.xml                 # Maven dependencies
│       └── src/
│           ├── main/
│           │   ├── java/...        # Application source code
│           │   └── resources/
│           │       ├── application.yml
│           │       └── application-docker.yml
│           └── test/               # Unit & integration tests
│
└── infra/
    ├── mysql/
    │   ├── master/
    │   │   └── my.cnf              # MySQL master configuration
    │   ├── slave/
    │   │   └── my.cnf              # MySQL slave configuration
    │   └── init.sql                # Database initialization script
    │
    └── redis/
        ├── redis-master.conf       # Redis master configuration
        └── redis-slave.conf        # Redis slave configuration
```

---

## 🔄 CI/CD Pipeline

The project uses **GitHub Actions** for continuous integration and deployment:

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Commit  │───▶│  Build   │───▶│  Test    │───▶│  Deploy  │
│  Push    │    │  & Lint  │    │  Suite   │    │  Azure   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

### Pipeline stages:

1. **Build** — Compile Java sources, resolve Maven dependencies
2. **Test** — Run unit tests, integration tests, and generate coverage reports
3. **Docker Build** — Build container images for all services
4. **Push** — Push images to Azure Container Registry (ACR)
5. **Deploy** — Deploy to Azure Container Instances or AKS

### Environment branches:

| Branch    | Environment  | Auto Deploy |
|-----------|--------------|-------------|
| `develop` | Development  | ✅          |
| `staging` | Staging      | ✅          |
| `main`    | Production   | 🔒 Manual   |

---

## ☁️ Azure Deployment

### Infrastructure overview:

- **Azure Container Registry (ACR)** — Private Docker image registry
- **Azure Container Instances (ACI)** or **Azure Kubernetes Service (AKS)** — Container orchestration
- **Azure Database for MySQL** — Managed MySQL with read replicas
- **Azure Cache for Redis** — Managed Redis with failover
- **Azure CDN** — Global static asset delivery

### Deployment steps:

```bash
# Login to Azure
az login

# Create resource group
az group create --name food-app-rg --location eastus

# Create ACR
az acr create --resource-group food-app-rg --name foodappacr --sku Basic

# Build and push images
az acr build --registry foodappacr --image food-core:latest ./services/food-core
az acr build --registry foodappacr --image notification-service:latest ./services/notification-service
```

> See the [Azure deployment guide](docs/azure-deployment.md) for full instructions.

---

## 🌍 Azure CDN Configuration

Azure CDN provides edge caching for static assets, reducing latency globally:

- **Profile**: Standard Microsoft CDN
- **Endpoint**: `https://<your-app>.azureedge.net`
- **Origin**: Nginx gateway (`http://localhost`)
- **Caching rules**:
  - Static assets (`/static/*`): 7-day TTL
  - API responses: No caching (pass-through)
  - Images: 30-day TTL with query string caching

### CDN setup:

```bash
# Create CDN profile
az cdn profile create --name food-cdn-profile \
  --resource-group food-app-rg \
  --sku Standard_Microsoft

# Create CDN endpoint
az cdn endpoint create --name food-cdn-endpoint \
  --profile-name food-cdn-profile \
  --resource-group food-app-rg \
  --origin <your-app-domain>
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Code standards:

- Follow [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- Write unit tests for all new features (minimum 80% coverage)
- Update documentation for API changes
- Use conventional commit messages

### Branch naming:

| Type       | Pattern                     | Example                        |
|------------|-----------------------------|--------------------------------|
| Feature    | `feature/<description>`     | `feature/order-tracking`       |
| Bug Fix    | `fix/<description>`         | `fix/cart-calculation`         |
| Hotfix     | `hotfix/<description>`      | `hotfix/payment-timeout`       |
| Chore      | `chore/<description>`       | `chore/update-dependencies`    |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ for scale
</p>
