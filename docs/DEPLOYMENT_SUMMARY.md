# Deployment Summary for Your Domains

## Your Domains
- **API:** `exam-app-api.duckdns.org`
- **Chat:** `backend-chat.duckdns.org`

## Quick Deployment Steps

### 1. On Your Server

```bash
# Install Docker, Nginx, Certbot
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo apt install nginx certbot python3-certbot-nginx -y

# Clone repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app

# Create .env files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env
nano backend-api/.env  # Add MongoDB URI
nano backend-chat/.env  # Add MongoDB URI
```

### 2. Update docker-compose.yml for Production

**Important:** For production with Nginx, use `expose` instead of `ports`:

```yaml
services:
  api:
    expose:
      - "3000"  # Internal only
  chat:
    expose:
      - "3001"  # Internal only
```

Or use the provided `docker-compose.production.yml` file.

### 3. Setup Nginx Reverse Proxy

```bash
# Copy Nginx configs
sudo cp nginx/exam-app-api.duckdns.org.conf /etc/nginx/sites-available/
sudo cp nginx/backend-chat.duckdns.org.conf /etc/nginx/sites-available/

# Enable sites
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Start Docker Containers

```bash
# Build and start
docker-compose up -d --build

# Verify
docker ps
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### 5. Setup SSL (HTTPS)

```bash
# Get SSL certificates
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org
```

### 6. Update .env Files

**backend-api/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### 7. Restart Containers

```bash
docker-compose restart
```

### 8. Test

```bash
curl https://exam-app-api.duckdns.org/health
curl https://backend-chat.duckdns.org/health
```

### 9. Update Flutter App

The app is already configured with your domains in `api_discovery_service.dart`. Just build:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://exam-app-api.duckdns.org \
  --dart-define=CHAT_BASE_URL=https://backend-chat.duckdns.org
```

## Architecture

```
Internet → Nginx (ports 80/443) → Docker Containers (ports 3000/3001 internal)
```

- **Nginx** handles SSL and routes traffic
- **Docker containers** are only accessible via Nginx (not exposed to internet)
- **Security:** Only ports 80 and 443 are open to the internet

## Files Created

- `SERVER_DEPLOYMENT_WITH_DOMAINS.md` - Complete deployment guide
- `QUICK_SERVER_DEPLOYMENT.md` - Quick reference
- `nginx/exam-app-api.duckdns.org.conf` - Nginx config for API
- `nginx/backend-chat.duckdns.org.conf` - Nginx config for Chat
- `docker-compose.production.yml` - Production Docker Compose config
- `deploy-server.sh` - Automated deployment script

## Next Steps

1. Follow `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for detailed instructions
2. Test your endpoints
3. Build and distribute your Flutter app
4. Monitor logs and performance

## Troubleshooting

See `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for detailed troubleshooting steps.

