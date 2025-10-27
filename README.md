# Blue/Green Deployment with Nginx Auto-Failover

## 📖 Overview

This project implements a Blue/Green deployment strategy for a Node.js application using Nginx as a reverse proxy with automatic failover capabilities. When the active service fails, Nginx automatically routes traffic to the backup service with zero downtime.

## 🏗️ Architecture

```
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                    http://localhost:8080
                           │
                    ┌──────▼──────┐
                    │    Nginx    │
                    │ Load Balancer│
                    └──┬────────┬──┘
                       │        │
            ┌──────────┘        └──────────┐
            │                              │
     ┌──────▼─────┐                 ┌──────▼─────┐
     │  Blue App  │                 │ Green App  │
     │ (Primary)  │                 │ (Backup)   │
     │ Port: 8081 │                 │ Port: 8082 │
     └────────────┘                 └────────────┘
```

## ✨ Features

- **Automatic Failover**: Nginx detects failures and switches to backup instantly
- **Zero Downtime**: Failed requests are retried on backup within the same client request
- **Health Checks**: Continuous monitoring of both services
- **Header Preservation**: X-App-Pool and X-Release-Id headers forwarded to clients
- **Manual Toggle**: Switch active pool by changing ACTIVE_POOL in .env

## 🚀 Quick Start

### Prerequisites

- Docker Desktop for Windows
- Git
- PowerShell

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd devops-blue-green
   ```

2. **Configure environment**
   ```bash
   # Copy the example env file
   cp .env.example .env
   
   # Edit .env if needed
   ```

3. **Run setup script**
   ```powershell
   # PowerShell
   .\setup.ps1
   ```

   Or manually:
   ```bash
   # Generate nginx config
   # On Windows with Git Bash:
   export ACTIVE_POOL=blue
   export BACKUP_POOL=green
   export PORT=3000
   envsubst < nginx.conf.template > nginx.conf
   
   # Start services
   docker-compose up -d
   ```

## 📡 Endpoints

- **Main Service**: http://localhost:8080/version
- **Blue Direct**: http://localhost:8081/version
- **Green Direct**: http://localhost:8082/version
- **Health Check**: http://localhost:8080/healthz

## 🧪 Testing Failover

### Test Automatic Failover

1. **Check initial state** (should show Blue):
   ```powershell
   curl http://localhost:8080/version
   ```

2. **Trigger chaos on Blue**:
   ```powershell
   curl -X POST http://localhost:8081/chaos/start?mode=error
   ```

3. **Verify automatic switch to Green**:
   ```powershell
   curl http://localhost:8080/version
   # Should now show X-App-Pool: green
   ```

4. **Stop chaos**:
   ```powershell
   curl -X POST http://localhost:8081/chaos/stop
   ```

### Test Manual Pool Toggle

1. **Edit .env file**:
   ```env
   ACTIVE_POOL=green  # Change from blue to green
   ```

2. **Regenerate nginx config and reload**:
   ```powershell
   .\setup.ps1
   ```

## 🔧 Configuration

### Environment Variables (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| BLUE_IMAGE | Docker image for Blue | ghcr.io/hngprojects/stage-2-devops-app:latest |
| GREEN_IMAGE | Docker image for Green | ghcr.io/hngprojects/stage-2-devops-app:latest |
| ACTIVE_POOL | Active service (blue/green) | blue |
| RELEASE_ID_BLUE | Blue release identifier | blue-v1.0.0 |
| RELEASE_ID_GREEN | Green release identifier | green-v1.0.0 |
| PORT | Internal app port | 3000 |
| NGINX_PORT | Public nginx port | 8080 |
| BLUE_PORT | Blue direct access port | 8081 |
| GREEN_PORT | Green direct access port | 8082 |

### Nginx Failover Settings

- **Max Fails**: 2 (marks server down after 2 failures)
- **Fail Timeout**: 5s (server marked down for 5 seconds)
- **Proxy Timeout**: 2-3s (fast failure detection)
- **Retry Policy**: Retries on error, timeout, 5xx responses

## 📊 Monitoring

Check service status:
```bash
docker-compose ps
```

View logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f app_blue
docker-compose logs -f app_green
```

## 🛑 Stopping Services

```bash
docker-compose down
```

## 📝 Project Structure

```
devops-blue-green/
├── docker-compose.yml       # Service orchestration
├── nginx.conf.template      # Nginx configuration template
├── nginx.conf              # Generated nginx config
├── .env                    # Environment variables
├── .env.example            # Example environment file
├── setup.ps1               # Windows setup script
├── README.md               # This file
└── DECISION.md             # Implementation decisions
```

## 🐛 Troubleshooting

### Services won't start
```bash
# Check Docker is running
docker version

# Check ports aren't in use
netstat -ano | findstr :8080
netstat -ano | findstr :8081
netstat -ano | findstr :8082
```

### Failover not working
- Verify nginx.conf was generated correctly
- Check max_fails and fail_timeout settings
- Ensure both apps are healthy: visit /healthz endpoints

### Headers not showing
- Confirm apps are returning headers (check direct ports)
- Verify nginx proxy_pass_request_headers is on
- Check no header filtering in nginx config

## 📚 Additional Resources

- [Nginx Upstream Documentation](http://nginx.org/en/docs/http/ngx_http_upstream_module.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Blue-Green Deployment Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)

## 👤 Author

[Your Name]
- GitHub: [@yourusername](https://github.com/yourusername)

## 📄 License

This project is part of the HNG DevOps Internship Stage 2.
