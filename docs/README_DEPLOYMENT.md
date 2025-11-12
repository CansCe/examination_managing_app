# Deployment Guide - Quick Reference

## Your Domains

- **API Service**: `exam-app-api.duckdns.org` (or `api.yourdomain.com`)
- **Chat Service**: `backend-chat.duckdns.org` (or `chat.yourdomain.com`)

## Choose Your Deployment Method

### Option 1: Production Server with Nginx (Recommended)

**Use:** [SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md)

Complete guide for deploying to a production server with:
- Nginx reverse proxy
- SSL/HTTPS certificates (Let's Encrypt)
- Docker containers
- Domain routing

**Best for:** Production deployments with custom domains

### Option 2: Docker Deployment

**Use:** [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)

Deploy using Docker Compose for:
- Local development
- Quick testing
- Containerized deployment

**Best for:** Local development and testing

### Option 3: Manual Server Deployment

**Use:** [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)

Deploy services manually with PM2 for:
- Full control over services
- Custom configurations
- Non-Docker environments

**Best for:** Servers without Docker or custom setups

## Quick Start

### 1. Local Development

```bash
# Start backend services
cd backend-api && npm install && npm start
cd ../backend-chat && npm install && npm start

# Run Flutter app
flutter run
```

### 2. Docker Deployment

```bash
# Configure .env files
cd backend-api && cp ENV_EXAMPLE.txt .env
cd ../backend-chat && cp ENV_EXAMPLE.txt .env

# Start services
docker-compose up -d

# Verify
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### 3. Production Deployment

```bash
# On server: Clone repository
git clone <repository-url> /var/www/exam-management-app
cd /var/www/exam-management-app

# Configure environment
cd backend-api && cp ENV_EXAMPLE.txt .env && nano .env
cd ../backend-chat && cp ENV_EXAMPLE.txt .env && nano .env

# Start with Docker
docker-compose up -d

# Or start with PM2
cd backend-api && pm2 start server.js --name exam-api
cd ../backend-chat && pm2 start server.js --name exam-chat
```

## Configuration Checklist

- [ ] MongoDB connection string configured
- [ ] Environment variables set in `.env` files
- [ ] CORS origins configured
- [ ] Ports 3000 and 3001 available
- [ ] Domain names configured (if using domains)
- [ ] SSL certificates installed (for HTTPS)
- [ ] Firewall rules configured
- [ ] Nginx reverse proxy configured (if using)

## Update Flutter App

After deploying backend services, update the Flutter app:

1. **Edit `lib/services/api_discovery_service.dart`**
   ```dart
   static final List<String> _defaultApiUrls = [
     'https://exam-app-api.duckdns.org',
     'http://exam-app-api.duckdns.org',
   ];
   
   static final List<String> _defaultChatUrls = [
     'https://backend-chat.duckdns.org',
     'http://backend-chat.duckdns.org',
   ];
   ```

2. **Rebuild app**
   ```bash
   flutter build apk --release
   # or
   flutter build ios --release
   ```

## Verification

### Test Backend Services

```bash
# API Service
curl http://localhost:3000/health
curl https://exam-app-api.duckdns.org/health

# Chat Service
curl http://localhost:3001/health
curl https://backend-chat.duckdns.org/health
```

### Test from Flutter App

- Launch the app
- Check console logs for API discovery
- Verify connection to production endpoints
- Test chat functionality

## Troubleshooting

### Services Not Accessible

- Check Docker containers: `docker-compose ps`
- Check service logs: `docker-compose logs -f`
- Verify environment variables
- Check MongoDB connection
- Verify ports are not in use

### SSL Certificate Issues

- Verify domain DNS records
- Check certificate expiration: `sudo certbot certificates`
- Renew certificates: `sudo certbot renew`

### App Can't Connect

- Verify backend services are running
- Check CORS configuration
- Verify domain names in API discovery
- Check network connectivity

## Documentation Files

- **[QUICK_START.md](QUICK_START.md)** - Quick setup guide
- **[BACKEND_SETUP.md](BACKEND_SETUP.md)** - Backend configuration
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - General deployment guide
- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Docker setup
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Production server setup
- **[SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md)** - Domain setup guide

## Security Checklist

- [ ] Use HTTPS for all services
- [ ] Configure CORS properly
- [ ] Enable rate limiting
- [ ] Use environment variables for secrets
- [ ] Keep dependencies updated
- [ ] Enable MongoDB authentication
- [ ] Configure firewall rules
- [ ] Set up monitoring and logging
- [ ] Regular backups

---