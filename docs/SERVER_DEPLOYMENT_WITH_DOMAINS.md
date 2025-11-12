# Server Deployment with Domain Names

Complete guide for deploying the Exam Management App to a production server with domain names.

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Domain names configured (e.g., DuckDNS, custom domain)
- Docker and Docker Compose installed
- Nginx installed
- MongoDB Atlas account or MongoDB instance
- SSL certificates (Let's Encrypt recommended)

## Domain Setup

### Option 1: DuckDNS (Free)

1. **Create DuckDNS account** at https://www.duckdns.org
2. **Create domains**:
   - `exam-app-api.duckdns.org` (for API service)
   - `backend-chat.duckdns.org` (for chat service)
3. **Update IP address**:
   ```bash
   curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip="
   ```

### Option 2: Custom Domain

1. **Purchase domain** from registrar (Namecheap, GoDaddy, etc.)
2. **Create subdomains**:
   - `api.yourdomain.com` (for API service)
   - `chat.yourdomain.com` (for chat service)
3. **Point DNS records** to your server IP:
   - A record: `api.yourdomain.com` → `YOUR_SERVER_IP`
   - A record: `chat.yourdomain.com` → `YOUR_SERVER_IP`

## Server Setup

### 1. Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 2. Install Nginx

```bash
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 3. Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

## Application Deployment

### 1. Clone Repository

```bash
cd /var/www
sudo git clone <repository-url> exam-management-app
cd exam-management-app
```

### 2. Configure Environment Files

**Backend API:**
```bash
cd backend-api
cp ENV_EXAMPLE.txt .env
nano .env
```

```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
```

**Chat Service:**
```bash
cd ../backend-chat
cp ENV_EXAMPLE.txt .env
nano .env
```

```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

### 3. Start Services with Docker

```bash
cd /var/www/exam-management-app
docker-compose up -d
```

### 4. Verify Services

```bash
# Check containers
docker-compose ps

# Check logs
docker-compose logs

# Test health endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health
```

## Nginx Configuration

### 1. Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/exam-app
```

### 2. API Service Configuration

```nginx
# API Service
server {
    listen 80;
    server_name exam-app-api.duckdns.org;  # or api.yourdomain.com
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### 3. Chat Service Configuration

```nginx
# Chat Service
server {
    listen 80;
    server_name backend-chat.duckdns.org;  # or chat.yourdomain.com
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 4. Enable Site

```bash
sudo ln -s /etc/nginx/sites-available/exam-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## SSL/TLS Setup

For detailed HTTPS upgrade instructions with prerequisites, troubleshooting, and best practices, see **[docs/HTTPS_UPGRADE.md](HTTPS_UPGRADE.md)**.

### Quick Setup

```bash
# For DuckDNS domains
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org

# For custom domains
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

### Auto-Renewal

Certbot automatically sets up renewal. Test:

```bash
sudo certbot renew --dry-run
```

**Note:** For comprehensive HTTPS upgrade guide including prerequisites, conditions, troubleshooting, and security best practices, refer to [HTTPS_UPGRADE.md](HTTPS_UPGRADE.md).

## Firewall Configuration

### Configure UFW

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## Update Flutter App

### 1. Update API Discovery

Edit `lib/services/api_discovery_service.dart`:

```dart
static final List<String> _defaultApiUrls = [
  // Production (HTTPS first)
  'https://exam-app-api.duckdns.org',
  'https://api.yourdomain.com',  // If using custom domain
  
  // Production fallback (HTTP)
  'http://exam-app-api.duckdns.org',
  'http://api.yourdomain.com',
  
  // Development (only for debug builds)
  if (kDebugMode) 'http://localhost:3000',
  if (kDebugMode) 'http://10.0.2.2:3000',
];

static final List<String> _defaultChatUrls = [
  // Production (HTTPS first)
  'https://backend-chat.duckdns.org',
  'https://chat.yourdomain.com',  // If using custom domain
  
  // Production fallback (HTTP)
  'http://backend-chat.duckdns.org',
  'http://chat.yourdomain.com',
  
  // Development (only for debug builds)
  if (kDebugMode) 'http://localhost:3001',
  if (kDebugMode) 'http://10.0.2.2:3001',
];
```

### 2. Rebuild App

```bash
flutter build apk --release
# or
flutter build ios --release
```

## Verification

### 1. Test API Service

```bash
# HTTP
curl http://exam-app-api.duckdns.org/health

# HTTPS
curl https://exam-app-api.duckdns.org/health
```

### 2. Test Chat Service

```bash
# HTTP
curl http://backend-chat.duckdns.org/health

# HTTPS
curl https://backend-chat.duckdns.org/health
```

### 3. Test from Flutter App

- Launch the app
- Check console logs for API discovery
- Verify connection to production endpoints

## Maintenance

### Update Application

```bash
cd /var/www/exam-management-app
git pull
docker-compose down
docker-compose up -d --build
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f chat
```

### Restart Services

```bash
docker-compose restart
# or
docker-compose restart api
docker-compose restart chat
```

## Troubleshooting

### Services Not Accessible

- Check Docker containers: `docker-compose ps`
- Check Nginx status: `sudo systemctl status nginx`
- Check firewall: `sudo ufw status`
- Check DNS resolution: `nslookup exam-app-api.duckdns.org`

### SSL Certificate Issues

- Verify domain DNS records
- Check certificate expiration: `sudo certbot certificates`
- Renew certificates: `sudo certbot renew`

### Connection Errors in App

- Verify backend services are running
- Check CORS configuration in `.env` files
- Verify domain names in API discovery service
- Check network connectivity

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