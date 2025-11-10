# Production Deployment Guide

This guide explains how to deploy the backend services to a dedicated server and configure the Flutter mobile app to connect to it.

## Table of Contents
1. [Server Setup](#server-setup)
2. [Backend Deployment](#backend-deployment)
3. [Flutter App Configuration](#flutter-app-configuration)
4. [Building for Production](#building-for-production)
5. [Distribution](#distribution)

---

## Server Setup

### Prerequisites
- A server with Docker and Docker Compose installed
- Domain name or alternative (see [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md) for options)
- MongoDB Atlas account or MongoDB instance
- Ports 3000 and 3001 accessible (or configure reverse proxy)

### Domain Options

**You have several options for API endpoints:**

1. **Purchase a Domain** (Recommended for Production)
   - Cost: $10-15/year
   - Professional and secure
   - See [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md) for details

2. **Free Dynamic DNS** (Good for Testing/Small Projects)
   - Services: DuckDNS, No-IP
   - Cost: Free
   - Example: `yourapp.duckdns.org`
   - See [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md) for setup

3. **IP Address** (Development Only)
   - Cost: Free
   - ⚠️ Not secure for production
   - Use only for local testing
   - Example: `http://192.168.1.100:3000`

**For detailed domain setup instructions, see [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)**

### Server Requirements
- **Minimum:** 2 CPU cores, 4GB RAM, 20GB storage
- **Recommended:** 4 CPU cores, 8GB RAM, 50GB storage
- **OS:** Ubuntu 20.04+ / Debian 11+ / CentOS 8+ (or any Linux with Docker support)

---

## Backend Deployment

### Step 1: Prepare Server

```bash
# SSH into your server
ssh user@your-server-ip

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 2: Clone Repository

```bash
# Clone your repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app
```

### Step 3: Configure Environment Variables

**SECURITY: .env files are NOT copied into Docker images.** They are loaded at runtime from the host.

**Create .env files on the server (not in Docker images):**

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
DEFAULT_ADMIN_ID=optional-admin-objectid
```

**Copy from examples:**
```bash
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env
# Edit the .env files with your actual credentials
nano backend-api/.env
nano backend-chat/.env
```

**Verify .env files exist:**
```bash
ls -la backend-api/.env
ls -la backend-chat/.env
```

### Step 4: Start Docker Services

```bash
# Start both services
docker-compose up -d

# Check status
docker ps

# View logs
docker-compose logs -f
```

### Step 5: Configure Firewall

```bash
# Allow ports 3000 and 3001 (if not using reverse proxy)
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp

# Or use iptables
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3001 -j ACCEPT
```

### Step 6: Setup Reverse Proxy (Recommended for HTTPS)

**Using Nginx:**

```nginx
# /etc/nginx/sites-available/exam-management-api
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

# /etc/nginx/sites-available/exam-management-chat
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

**Setup SSL with Let's Encrypt:**
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificates
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

---

## Flutter App Configuration

### Option 1: Build-Time Configuration (Recommended)

Configure the API URLs during the build process using `--dart-define`:

#### Android APK:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### Android App Bundle (for Play Store):
```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### iOS:
```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### Using IP Address (if no domain):
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://192.168.1.100:3000 \
  --dart-define=CHAT_BASE_URL=http://192.168.1.100:3001
```

**Note:** Replace `192.168.1.100` with your server's IP address.

### Option 2: Manual Configuration

Edit `lib/config/api_config.dart` directly:

```dart
class ApiConfig {
  static String get baseUrl {
    // Production server
    return 'https://api.yourdomain.com';
  }
  
  static String get chatBaseUrl {
    // Production server
    return 'https://chat.yourdomain.com';
  }
}
```

Then build normally:
```bash
flutter build apk --release
```

---

## Building for Production

### Android

#### 1. Generate Keystore (first time only)
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### 2. Configure Signing
Create `android/key.properties`:
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

#### 3. Build Release APK
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### 4. Build App Bundle (for Play Store)
```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

### iOS

#### 1. Configure Xcode
- Open `ios/Runner.xcworkspace` in Xcode
- Set up signing & capabilities
- Configure app identifier

#### 2. Build Release
```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

#### 3. Archive and Upload
- Open Xcode
- Product → Archive
- Distribute App

---

## Distribution

### Android

1. **Google Play Store:**
   - Build app bundle: `flutter build appbundle --release --dart-define=...`
   - Upload to Google Play Console
   - Configure store listing
   - Submit for review

2. **Direct Distribution (APK):**
   - Build APK: `flutter build apk --release --dart-define=...`
   - Distribute APK file directly
   - Users need to enable "Install from unknown sources"

### iOS

1. **App Store:**
   - Build and archive in Xcode
   - Upload to App Store Connect
   - Submit for review

2. **TestFlight:**
   - Upload to TestFlight
   - Invite testers
   - Test before public release

---

## Configuration Examples

### Example 1: Server with Domain (HTTPS)

**Server:** `api.yourdomain.com` and `chat.yourdomain.com`

**Build Command:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

### Example 2: Server with IP Address (HTTP)

**Server:** `192.168.1.100`

**Build Command:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://192.168.1.100:3000 \
  --dart-define=CHAT_BASE_URL=http://192.168.1.100:3001
```

**Note:** For production, use HTTPS with a domain name for security.

### Example 3: Local Development

**No build flags needed** - uses default localhost URLs:
```bash
flutter run
```

---

## Testing Production Build

### 1. Test API Connection
```bash
# Test API health
curl https://api.yourdomain.com/health

# Test Chat health
curl https://chat.yourdomain.com/health
```

### 2. Test from Mobile App
1. Install the production APK/IPA on a device
2. Connect to the same network (or use mobile data)
3. Login and test all features
4. Verify chat functionality
5. Check WebSocket connection

### 3. Debug Connection Issues

**Check API Config:**
Add this to your app (temporarily) to see current config:
```dart
print('API Config: ${ApiConfig.currentConfig}');
```

**Common Issues:**
- **"Connection refused"**: Server not running or firewall blocking
- **"SSL/TLS error"**: Certificate issue or HTTP instead of HTTPS
- **"CORS error"**: Update `ALLOWED_ORIGINS` in backend `.env`
- **"WebSocket failed"**: Check reverse proxy WebSocket configuration

---

## Security Considerations

### 1. Use HTTPS in Production
- Always use HTTPS for production APIs
- Get SSL certificates (Let's Encrypt is free)
- Configure reverse proxy with SSL

### 2. API Security
- Use environment variables for sensitive data
- Don't hardcode API keys in the app
- Implement API authentication
- Use rate limiting

### 3. Network Security
- Configure firewall rules
- Use VPN for sensitive deployments
- Monitor server logs
- Set up intrusion detection

---

## Monitoring and Maintenance

### 1. Server Monitoring
```bash
# Check Docker containers
docker ps

# View logs
docker-compose logs -f

# Check resource usage
docker stats
```

### 2. Application Monitoring
- Set up logging (e.g., Winston, Morgan)
- Monitor API response times
- Track error rates
- Set up alerts

### 3. Updates
```bash
# Pull latest code
git pull

# Rebuild containers
docker-compose up -d --build

# Restart services
docker-compose restart
```

---

## Quick Reference

### Build Commands

**Android (APK):**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

**Android (App Bundle):**
```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

**iOS:**
```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

### Server Commands

**Start services:**
```bash
docker-compose up -d
```

**Stop services:**
```bash
docker-compose down
```

**View logs:**
```bash
docker-compose logs -f
```

**Restart services:**
```bash
docker-compose restart
```

---

## Support

For issues or questions:
1. Check server logs: `docker-compose logs`
2. Verify API URLs in app: `ApiConfig.currentConfig`
3. Test API endpoints: `curl https://api.yourdomain.com/health`
4. Check firewall and network configuration
5. Review this guide's troubleshooting section

---

## Next Steps

1. **Set up monitoring** (e.g., Prometheus, Grafana)
2. **Configure backups** for MongoDB
3. **Set up CI/CD** for automated deployments
4. **Implement logging** and error tracking
5. **Configure alerts** for service failures

