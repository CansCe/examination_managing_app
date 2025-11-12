# Docker Deployment Guide

This guide covers deploying the Exam Management App using Docker and Docker Compose.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- MongoDB Atlas account or MongoDB instance

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd exam_management_app
   ```

2. **Configure environment files**
   ```bash
   # Backend API
   cd backend-api
   cp ENV_EXAMPLE.txt .env
   # Edit .env with your MongoDB URI
   
   # Chat Service
   cd ../backend-chat
   cp ENV_EXAMPLE.txt .env
   # Edit .env with your MongoDB URI
   ```

3. **Start services**
   ```bash
   cd ..
   docker-compose up -d
   ```

4. **Verify services**
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:3001/health
   ```

## Docker Compose Configuration

The `docker-compose.yml` file defines two services:

### API Service

```yaml
api:
  build:
    context: ./backend-api
    dockerfile: Dockerfile
  container_name: exam-management-api
  ports:
    - "127.0.0.1:3000:3000"
  env_file:
    - ./backend-api/.env
  environment:
    - PORT=3000
    - NODE_ENV=production
  restart: unless-stopped
  networks:
    - exam-management-network
```

### Chat Service

```yaml
chat:
  build:
    context: ./backend-chat
    dockerfile: Dockerfile
  container_name: exam-management-chat
  ports:
    - "127.0.0.1:3001:3001"
  env_file:
    - ./backend-chat/.env
  environment:
    - PORT=3001
    - NODE_ENV=production
  restart: unless-stopped
  networks:
    - exam-management-network
```

## Environment Variables

### Backend API (.env)

```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### Chat Service (.env)

```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

## Docker Commands

### Start Services

```bash
# Start in detached mode
docker-compose up -d

# Start with logs
docker-compose up
```

### Stop Services

```bash
# Stop services
docker-compose stop

# Stop and remove containers
docker-compose down
```

### View Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs api
docker-compose logs chat

# Follow logs
docker-compose logs -f
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart api
```

### Rebuild Services

```bash
# Rebuild and restart
docker-compose up -d --build

# Rebuild specific service
docker-compose build api
docker-compose up -d api
```

## Dockerfiles

### Backend API Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Start service
CMD ["node", "server.js"]
```

### Chat Service Dockerfile

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY . .

# Expose port
EXPOSE 3001

# Start service
CMD ["node", "server.js"]
```

## Production Deployment

### With Nginx Reverse Proxy

1. **Update docker-compose.yml** to bind to localhost only:
   ```yaml
   ports:
     - "127.0.0.1:3000:3000"
   ```

2. **Configure Nginx** to proxy to containers:
   ```nginx
   server {
       listen 80;
       server_name api.yourdomain.com;
       
       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

### With SSL/TLS

Use Let's Encrypt with Certbot:

```bash
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

## Health Checks

Both services include health check endpoints:

```bash
# API Service
curl http://localhost:3000/health

# Chat Service
curl http://localhost:3001/health
```

Docker Compose health checks are configured:

```yaml
healthcheck:
  test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## Networking

Services are on a shared Docker network:

```yaml
networks:
  exam-management-network:
    driver: bridge
```

Services can communicate using container names:
- API Service: `exam-management-api`
- Chat Service: `exam-management-chat`

## Volume Mounting (Optional)

For persistent data or configuration:

```yaml
volumes:
  - ./backend-api/.env:/app/.env:ro
  - ./logs:/app/logs
```

## Resource Limits

Set resource limits for production:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

## Troubleshooting

### Containers Won't Start

- **Check logs**: `docker-compose logs`
- **Check environment**: Verify `.env` files exist
- **Check ports**: Ensure ports 3000 and 3001 are available
- **Check MongoDB**: Verify MongoDB connection string

### Services Can't Connect to MongoDB

- **Check network**: Ensure containers can reach MongoDB
- **Check credentials**: Verify MongoDB username/password
- **Check IP whitelist**: Add server IP to MongoDB Atlas whitelist

### Port Conflicts

- **Change ports**: Update `docker-compose.yml` port mappings
- **Kill processes**: Find and kill processes using ports

### Container Restarts

- **Check logs**: `docker-compose logs -f`
- **Check health**: Verify health check endpoints
- **Check resources**: Monitor container resource usage

## Updating Services

1. **Pull latest code**
   ```bash
   git pull
   ```

2. **Rebuild and restart**
   ```bash
   docker-compose up -d --build
   ```

3. **Verify services**
   ```bash
   docker-compose ps
   curl http://localhost:3000/health
   ```

## Backup and Restore

### Backup Configuration

```bash
# Backup .env files
tar -czf backup-env.tar.gz backend-api/.env backend-chat/.env

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
```

### Restore

```bash
# Restore .env files
tar -xzf backup-env.tar.gz

# Restore docker-compose.yml
cp docker-compose.yml.backup docker-compose.yml
```

## Monitoring

### Container Status

```bash
docker-compose ps
```

### Resource Usage

```bash
docker stats
```

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
```

## Security Best Practices

1. **Use .env files**: Never commit `.env` files to Git
2. **Bind to localhost**: Use `127.0.0.1:port` for internal services
3. **Use reverse proxy**: Nginx for SSL termination
4. **Keep images updated**: Regularly update base images
5. **Limit resources**: Set resource limits
6. **Use secrets**: For sensitive data, use Docker secrets
