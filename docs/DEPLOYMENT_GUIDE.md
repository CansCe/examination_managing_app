# Complete Deployment Guide

**Master guide for deploying the Exam Management App to production**

This comprehensive guide covers everything you need to deploy your app, from Docker setup to domain configuration to app distribution.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Deployment Overview](#deployment-overview)
3. [Backend Deployment (Docker)](#backend-deployment-docker)
4. [Domain Setup (DNS)](#domain-setup-dns)
5. [App Configuration](#app-configuration)
6. [Build & Distribution](#build--distribution)
7. [Troubleshooting](#troubleshooting)
8. [Related Guides](#related-guides)

---

## 🚀 Quick Start

### For First-Time Deployment

1. **Setup Domain** → [Domain Setup Guide](#domain-setup-dns)
2. **Deploy Backend** → [Docker Deployment](#backend-deployment-docker)
3. **Configure App** → [App Configuration](#app-configuration)
4. **Build App** → [Build & Distribution](#build--distribution)

### For Quick Reference

- **Docker Commands**: [Docker Quick Reference](#docker-quick-reference)
- **Domain Options**: [Domain Options](#domain-options)
- **Build Commands**: [Build Commands](#build-commands)

---

## 📖 Deployment Overview

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                  │
│              Auto-discovers API endpoints                │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ HTTPS/HTTP
                       │
┌──────────────────────┴──────────────────────────────────┐
│              Backend Services (Docker)                   │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │   API Service    │      │  Chat Service    │        │
│  │   (Port 3000)    │      │  (Port 3001)     │        │
│  └────────┬─────────┘      └────────┬─────────┘        │
│           │                          │                  │
└───────────┼──────────────────────────┼──────────────────┘
            │                          │
            └──────────┬───────────────┘
                       │
            ┌──────────┴──────────┐
            │   MongoDB Atlas     │
            │   (Database)        │
            └─────────────────────┘
```

### Components

1. **Backend Services** (Docker)
   - API Service (REST API)
   - Chat Service (Socket.io WebSockets)
   - Both connect to MongoDB

2. **Domain/DNS**
   - API endpoint (e.g., `api.yourdomain.com`)
   - Chat endpoint (e.g., `chat.yourdomain.com`)
   - Optional: Reverse proxy (Nginx)

3. **Mobile App** (Flutter)
   - Auto-discovers API endpoints
   - Connects to backend services
   - Works on Android and iOS

---

## 🐳 Backend Deployment (Docker)

### Prerequisites

- Server with Docker and Docker Compose installed
- MongoDB Atlas account or MongoDB instance
- Domain name (optional, but recommended)
- Ports 3000 and 3001 accessible

### Step-by-Step Deployment

#### Step 1: Prepare Server

```bash
# SSH into your server
ssh user@your-server-ip

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

#### Step 2: Clone Repository

```bash
# Clone your repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app
```

#### Step 3: Configure Environment Variables

**Backend API (`backend-api/.env`):**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

**Backend Chat (`backend-chat/.env`):**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com,https://api.yourdomain.com,https://chat.yourdomain.com
```

#### Step 4: Start Docker Services

```bash
# Start both services
docker-compose up -d

# Check status
docker ps

# View logs
docker-compose logs -f

# Check service health
curl http://localhost:3000/health
curl http://localhost:3001/health
```

#### Step 5: Configure Firewall

```bash
# Allow ports 3000 and 3001
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp

# Or use iptables
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3001 -j ACCEPT
```

### Docker Quick Reference

**Start Services:**
```bash
docker-compose up -d
```

**Stop Services:**
```bash
docker-compose down
```

**View Logs:**
```bash
docker-compose logs -f
docker-compose logs -f api
docker-compose logs -f chat
```

**Restart Services:**
```bash
docker-compose restart
docker-compose restart api
docker-compose restart chat
```

**Rebuild After Code Changes:**
```bash
docker-compose up -d --build
```

**Check Service Status:**
```bash
docker ps
docker-compose ps
```

**Execute Commands in Container:**
```bash
docker exec -it exam-management-api node -v
docker exec -it exam-management-chat node -v
```

### Related Guides

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Detailed Docker deployment guide
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Complete production deployment guide

---

## 🌐 Domain Setup (DNS)

### Domain Options

You have several options for API endpoints:

#### Option 1: Purchase a Domain (Recommended for Production)

**Cost:** $10-15/year  
**Best For:** Production, professional apps  
**Providers:** Namecheap, Google Domains, Cloudflare

**Steps:**
1. Purchase domain from a registrar
2. Configure DNS records (A records)
3. Setup SSL certificate (Let's Encrypt)
4. Configure reverse proxy (Nginx)

**See:** [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md) for detailed instructions

#### Option 2: Free Dynamic DNS (Good for Testing)

**Cost:** Free  
**Best For:** Testing, small projects  
**Services:** DuckDNS, No-IP

**Steps:**
1. Sign up for DuckDNS (free)
2. Create subdomain (e.g., `examapp`)
3. Install update script on server
4. Use subdomain in app (e.g., `examapp.duckdns.org`)

**See:** [QUICK_DOMAIN_SETUP.md](QUICK_DOMAIN_SETUP.md) for 5-minute setup

#### Option 3: IP Address (Development Only)

**Cost:** Free  
**Best For:** Local testing only  
**⚠️ Warning:** Not secure for production

**Usage:**
```bash
# Use server IP directly
http://192.168.1.100:3000
```

### DNS Configuration

#### For Purchased Domain

**1. Configure A Records:**
```
Type: A
Name: api
Value: YOUR_SERVER_IP
TTL: 3600

Type: A
Name: chat
Value: YOUR_SERVER_IP
TTL: 3600
```

**2. Setup SSL Certificate:**
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

**3. Configure Reverse Proxy (Nginx):**

```nginx
# /etc/nginx/sites-available/api.yourdomain.com
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

# /etc/nginx/sites-available/chat.yourdomain.com
server {
    listen 80;
    server_name chat.yourdomain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# WebSocket support for Socket.io
location /socket.io/ {
    proxy_pass http://localhost:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

#### For DuckDNS (Free)

**1. Sign Up:**
- Go to https://www.duckdns.org
- Sign in with GitHub/Google
- Create subdomain (e.g., `examapp`)

**2. Install Update Script:**
```bash
# On your server
mkdir -p ~/duckdns
echo 'echo url="https://www.duckdns.org/update?domains=examapp&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > ~/duckdns/duck.sh
chmod +x ~/duckdns/duck.sh

# Add to cron (update every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
```

**3. Use in App:**
```bash
# Your domain will be: examapp.duckdns.org
# API: http://examapp.duckdns.org:3000
# Chat: http://examapp.duckdns.org:3001
```

### Domain Comparison

| Method | Cost | Setup Time | Security | Professional | Best For |
|--------|------|------------|----------|--------------|----------|
| **Purchased Domain** | $10-15/year | 30 min | ✅ High (HTTPS) | ✅✅✅ | Production |
| **DuckDNS** | Free | 5 min | ⚠️ Medium (HTTP) | ✅✅ | Testing/Small Projects |
| **IP Address** | Free | 0 min | ❌ Low (HTTP) | ❌ | Development Only |

### Related Guides

- **[DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)** - Complete domain setup guide
- **[QUICK_DOMAIN_SETUP.md](QUICK_DOMAIN_SETUP.md)** - Quick 5-minute setup with DuckDNS

---

## 📱 App Configuration

### Auto-Discovery (Recommended)

The app automatically discovers available API endpoints on first launch.

**How It Works:**
1. App tries multiple potential endpoints
2. Uses first one that responds
3. Saves it locally for future use
4. Re-validates on each launch

**To Add Your Domains:**
1. Edit `lib/services/api_discovery_service.dart`
2. Add your domain URLs to the lists
3. Build the app normally (no special flags)

**See:** [AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md) for detailed instructions

### Manual Configuration

#### Build-Time Configuration

```bash
# Android
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com

# iOS
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### Runtime Configuration

Users can manually configure API URLs in app settings if auto-discovery fails.

### Configuration Priority

1. **Build-time configuration** (`--dart-define`) - Highest priority
2. **Discovered URL** (cached) - Auto-discovered
3. **Stored URL** (from previous session) - Local storage
4. **Localhost fallback** - Development default

### Related Guides

- **[AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md)** - Auto-discovery setup guide
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Production deployment guide

---

## 🔨 Build & Distribution

### Build Commands

#### Android APK

```bash
# With auto-discovery (recommended)
flutter build apk --release

# With manual configuration
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### Android App Bundle (Play Store)

```bash
# With auto-discovery (recommended)
flutter build appbundle --release

# With manual configuration
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### iOS

```bash
# With auto-discovery (recommended)
flutter build ios --release

# With manual configuration
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

### Build Scripts

**Linux/Mac:**
```bash
./build-production.sh android https://api.yourdomain.com https://chat.yourdomain.com
```

**Windows:**
```powershell
.\build-production.ps1 android https://api.yourdomain.com https://chat.yourdomain.com
```

### Distribution

#### Android

**Google Play Store:**
1. Build app bundle: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Configure store listing
4. Submit for review

**Direct Distribution:**
1. Build APK: `flutter build apk --release`
2. Share APK file directly
3. Users need to enable "Install from unknown sources"

#### iOS

**App Store:**
1. Build and archive in Xcode
2. Upload to App Store Connect
3. Submit for review

**TestFlight:**
1. Upload to TestFlight
2. Invite testers
3. Test before public release

### Related Guides

- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Complete production deployment guide
- **[build-production.sh](build-production.sh)** - Build script for Linux/Mac
- **[build-production.ps1](build-production.ps1)** - Build script for Windows

---

## 🔧 Troubleshooting

### Docker Issues

**Services Not Starting:**
```bash
# Check Docker status
docker ps
docker-compose ps

# View logs
docker-compose logs -f

# Check service health
curl http://localhost:3000/health
curl http://localhost:3001/health
```

**Connection Refused:**
```bash
# Check if ports are open
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :3001

# Check firewall
sudo ufw status
```

**Services Can't Connect to MongoDB:**
```bash
# Check MongoDB URI in .env files
cat backend-api/.env
cat backend-chat/.env

# Test MongoDB connection
docker exec -it exam-management-api node -e "require('mongodb').MongoClient.connect(process.env.MONGODB_URI).then(() => console.log('Connected'))"
```

### Domain/DNS Issues

**Domain Not Resolving:**
```bash
# Check DNS propagation
nslookup api.yourdomain.com
dig api.yourdomain.com

# Check DNS records
# Use online tools: https://www.whatsmydns.net
```

**SSL Certificate Issues:**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Test SSL
curl -I https://api.yourdomain.com/health
```

**WebSocket Connection Fails:**
```bash
# Check Nginx configuration
sudo nginx -t

# Check WebSocket support in Nginx config
# Ensure proxy_set_header Upgrade and Connection are set
```

### App Issues

**App Can't Connect to API:**
```bash
# Check API configuration
# In app: print(ApiConfig.currentConfig)

# Test API endpoint
curl https://api.yourdomain.com/health

# Check CORS settings in backend .env
cat backend-api/.env | grep ALLOWED_ORIGINS
```

**Auto-Discovery Not Working:**
```bash
# Check discovery logs in app console
# Verify domains are in discovery list
# Check network connectivity

# Force rediscovery
ApiConfig.rediscover()
```

**Chat Service Not Connecting:**
```bash
# Check chat service health
curl https://chat.yourdomain.com/health

# Check Socket.io connection
# Verify WebSocket URL (ws:// or wss://)
# Check CORS settings
```

### Common Solutions

**"Connection refused"**
- Check Docker services are running
- Verify firewall allows connections
- Check ports are exposed correctly

**"SSL/TLS error"**
- Ensure using HTTPS URLs
- Check SSL certificate is valid
- Verify certificate is not expired

**"CORS error"**
- Update `ALLOWED_ORIGINS` in backend `.env`
- Include your app's origin in CORS settings
- Check reverse proxy configuration

**"Domain not found"**
- Wait 24-48 hours for DNS propagation
- Check DNS records are correct
- Verify domain is pointing to correct IP

### Related Guides

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Docker troubleshooting
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Production troubleshooting
- **[DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)** - Domain troubleshooting

---

## 📚 Related Guides

### Deployment Guides

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Local development with Docker
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Complete production deployment guide
- **[QUICK_START_PRODUCTION.md](QUICK_START_PRODUCTION.md)** - Quick start guide for production

### Domain & DNS Guides

- **[DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)** - Complete domain setup guide
- **[QUICK_DOMAIN_SETUP.md](QUICK_DOMAIN_SETUP.md)** - Quick 5-minute setup with DuckDNS

### App Configuration Guides

- **[AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md)** - Auto-discovery API setup guide
- **[README.md](README.md)** - Main project README

### Build Scripts

- **[build-production.sh](build-production.sh)** - Build script for Linux/Mac
- **[build-production.ps1](build-production.ps1)** - Build script for Windows

### Configuration Files

- **[docker-compose.yml](docker-compose.yml)** - Docker Compose configuration
- **[lib/config/api_config.dart](lib/config/api_config.dart)** - API configuration
- **[lib/services/api_discovery_service.dart](lib/services/api_discovery_service.dart)** - API discovery service

---

## 🎯 Deployment Checklist

### Pre-Deployment

- [ ] Server prepared (Docker installed)
- [ ] MongoDB Atlas account created
- [ ] Domain purchased or DuckDNS setup
- [ ] Environment variables configured
- [ ] Firewall rules configured

### Backend Deployment

- [ ] Docker services started
- [ ] Services health checks passing
- [ ] MongoDB connection working
- [ ] API endpoints accessible
- [ ] Chat service accessible

### Domain Setup

- [ ] DNS records configured
- [ ] SSL certificates installed
- [ ] Reverse proxy configured (if using)
- [ ] WebSocket support enabled
- [ ] Domain resolving correctly

### App Configuration

- [ ] Domains added to discovery list
- [ ] App built and tested
- [ ] Auto-discovery working
- [ ] API connection verified
- [ ] Chat connection verified

### Distribution

- [ ] App built for production
- [ ] App tested on devices
- [ ] App uploaded to stores
- [ ] Store listings configured
- [ ] App published

---

## 🚀 Quick Deployment Paths

### Path 1: Quick Test Setup (5 minutes)

1. **Setup DuckDNS** (free domain)
2. **Deploy Docker services**
3. **Build app with auto-discovery**
4. **Test and distribute**

**See:** [QUICK_DOMAIN_SETUP.md](QUICK_DOMAIN_SETUP.md)

### Path 2: Production Setup (30 minutes)

1. **Purchase domain** ($10-15/year)
2. **Deploy Docker services**
3. **Configure DNS and SSL**
4. **Setup reverse proxy**
5. **Build app with domains**
6. **Distribute to stores**

**See:** [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)

### Path 3: Full Production Setup (1 hour)

1. **Purchase domain**
2. **Setup Cloudflare** (free DNS + SSL)
3. **Deploy Docker services**
4. **Configure Nginx reverse proxy**
5. **Setup monitoring**
6. **Build and distribute app**
7. **Setup CI/CD**

**See:** [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)

---

## 📞 Support

### Getting Help

1. **Check troubleshooting section** above
2. **Review related guides** in the table of contents
3. **Check service logs**: `docker-compose logs`
4. **Verify configuration**: Check `.env` files
5. **Test endpoints**: Use `curl` to test APIs

### Useful Commands

```bash
# Check Docker status
docker ps
docker-compose ps

# View logs
docker-compose logs -f

# Test API endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check DNS
nslookup api.yourdomain.com
dig api.yourdomain.com

# Test SSL
curl -I https://api.yourdomain.com/health
```

---

## 📝 Summary

This deployment guide provides everything you need to deploy your Exam Management App to production:

1. **Docker Deployment** - Deploy backend services with Docker
2. **Domain Setup** - Configure DNS and SSL certificates
3. **App Configuration** - Setup auto-discovery or manual configuration
4. **Build & Distribution** - Build and distribute your app

**Next Steps:**
- Choose your deployment path (Quick Test, Production, or Full Production)
- Follow the step-by-step instructions
- Refer to related guides for detailed information
- Use the troubleshooting section if you encounter issues

**Good luck with your deployment! 🚀**

