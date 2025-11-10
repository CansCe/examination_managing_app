# Deployment Guide - Quick Start

## Your Domains
- **API:** `exam-app-api.duckdns.org`
- **Chat:** `backend-chat.duckdns.org`

## Choose Your Deployment Method

### Option 1: Production Server with Nginx (Recommended)

**Use:** `SERVER_DEPLOYMENT_WITH_DOMAINS.md`

This is the complete guide for deploying to a production server with:
- Nginx reverse proxy
- SSL/HTTPS certificates
- Docker containers
- Domain routing

**Steps:**
1. Install Docker, Nginx, Certbot on your server
2. Configure Nginx to proxy to Docker containers
3. Get SSL certificates
4. Start Docker containers
5. Update Flutter app

### Option 2: Quick Deployment

**Use:** `QUICK_SERVER_DEPLOYMENT.md`

Fast 5-minute deployment guide.

### Option 3: Local Development

**Use:** `DOCKER_DEPLOYMENT.md`

For local testing with Docker.

## File Structure

```
exam_management_app/
├── nginx/                              # Nginx configuration files
│   ├── exam-app-api.duckdns.org.conf  # API Nginx config
│   └── backend-chat.duckdns.org.conf  # Chat Nginx config
├── docker-compose.yml                  # Docker Compose (local dev)
├── docker-compose.production.yml       # Docker Compose (production)
├── deploy-server.sh                    # Automated deployment script
├── SERVER_DEPLOYMENT_WITH_DOMAINS.md   # Complete deployment guide ⭐
├── QUICK_SERVER_DEPLOYMENT.md          # Quick reference
└── DEPLOYMENT_SUMMARY.md               # This file
```

## Quick Commands

### On Server

```bash
# Start containers
docker-compose -f docker-compose.production.yml up -d

# Check status
docker ps

# View logs
docker-compose logs -f

# Restart
docker-compose restart
```

### Build Flutter App

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://exam-app-api.duckdns.org \
  --dart-define=CHAT_BASE_URL=https://backend-chat.duckdns.org
```

## Need Help?

1. Check `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for detailed instructions
2. Check troubleshooting section in deployment guides
3. Verify DNS resolution: `nslookup exam-app-api.duckdns.org`
4. Check container logs: `docker-compose logs -f`
5. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`

## Security Checklist

- [ ] SSL certificates installed
- [ ] Firewall configured (only ports 80, 443 open)
- [ ] Containers not exposed directly (only via Nginx)
- [ ] .env files not in Docker images
- [ ] Strong MongoDB credentials
- [ ] Regular backups

