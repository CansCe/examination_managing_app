# Deployment Guide

This guide covers deploying the Exam Management App to production, including both backend services and the Flutter mobile app.

## Deployment Overview

The application consists of:
- **Backend API Service**: REST API (port 3000)
- **Chat Service**: WebSocket chat (port 3001)
- **Flutter Mobile App**: iOS and Android apps
- **MongoDB Database**: MongoDB Atlas or self-hosted

## Prerequisites

- Server with Node.js 18.0.0+ installed
- Domain names (optional but recommended)
- MongoDB Atlas account or MongoDB instance
- SSL certificates (for HTTPS)
- Reverse proxy (Nginx recommended)

## Deployment Options

### Option 1: Docker Deployment (Recommended)

See [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for detailed Docker setup.

### Option 2: Manual Server Deployment

See [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for manual server setup.

### Option 3: Server with Domain Names

See [SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md) for domain setup.

## Quick Docker Deployment

1. **Prepare environment files**
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

2. **Start services with Docker Compose**
   ```bash
   cd ..
   docker-compose up -d
   ```

3. **Verify services**
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:3001/health
   ```

## Backend Services Deployment

### Environment Configuration

Both services require `.env` files with:

**backend-api/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
```

**backend-chat/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://chat.yourdomain.com
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

### Using PM2 (Process Manager)

1. **Install PM2**
   ```bash
   npm install -g pm2
   ```

2. **Start services with PM2**
   ```bash
   # API Service
   cd backend-api
   pm2 start server.js --name exam-api
   
   # Chat Service
   cd ../backend-chat
   pm2 start server.js --name exam-chat
   ```

3. **Save PM2 configuration**
   ```bash
   pm2 save
   pm2 startup
   ```

4. **Monitor services**
   ```bash
   pm2 status
   pm2 logs
   ```

## Nginx Reverse Proxy Setup

### Install Nginx

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
```

### Configure Nginx

Create `/etc/nginx/sites-available/exam-app`:

```nginx
# API Service
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

# Chat Service
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
    
    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Enable SSL with Let's Encrypt

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificates
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

### Enable Site

```bash
sudo ln -s /etc/nginx/sites-available/exam-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Flutter App Deployment

### Build for Production

**Android:**
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

### Update API Discovery

Before building, update `lib/services/api_discovery_service.dart` with your production domains:

```dart
static final List<String> _defaultApiUrls = [
  'https://api.yourdomain.com',
  'http://api.yourdomain.com',
];

static final List<String> _defaultChatUrls = [
  'https://chat.yourdomain.com',
  'http://chat.yourdomain.com',
];
```

### Publish to App Stores

**Android (Google Play):**
1. Build app bundle: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Complete store listing and submit for review

**iOS (App Store):**
1. Build iOS app: `flutter build ios --release`
2. Archive in Xcode
3. Upload to App Store Connect
4. Submit for review

## Security Checklist

- [ ] Use HTTPS for all services
- [ ] Configure CORS properly
- [ ] Enable rate limiting
- [ ] Use environment variables for secrets
- [ ] Keep dependencies updated
- [ ] Enable MongoDB authentication
- [ ] Use strong passwords
- [ ] Configure firewall rules
- [ ] Enable SSL/TLS certificates
- [ ] Set up monitoring and logging

## Monitoring

### Health Checks

Both services provide health check endpoints:
- API: `GET /health`
- Chat: `GET /health`

Set up monitoring to check these endpoints regularly.

### Logs

- **PM2 logs**: `pm2 logs`
- **Docker logs**: `docker-compose logs`
- **Nginx logs**: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

### Database Monitoring

Monitor MongoDB Atlas dashboard or set up MongoDB monitoring tools.

## Backup Strategy

1. **Database Backups**: Set up automated MongoDB Atlas backups
2. **Code Backups**: Use Git repository
3. **Configuration Backups**: Backup `.env` files securely
4. **SSL Certificates**: Backup SSL certificates

## Troubleshooting

### Services Won't Start

- Check MongoDB connection
- Verify environment variables
- Check port availability
- Review service logs

### App Can't Connect

- Verify backend services are running
- Check CORS configuration
- Verify domain names resolve correctly
- Check firewall rules

### SSL Certificate Issues

- Verify domain DNS records
- Check certificate expiration
- Renew certificates: `sudo certbot renew`

## Scaling

### Horizontal Scaling

- Use load balancer for multiple instances
- Configure MongoDB replica set
- Use Redis for session storage (if needed)

### Vertical Scaling

- Increase server resources
- Optimize database queries
- Use caching where appropriate

## Maintenance

### Regular Updates

- Update Node.js dependencies: `npm update`
- Update Flutter dependencies: `flutter pub upgrade`
- Keep MongoDB drivers updated
- Monitor security advisories

### Database Maintenance

- Regular backups
- Index optimization
- Cleanup old data (chat messages, etc.)

## Next Steps

- Read [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for Docker setup
- Read [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for detailed server setup
- Read [SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md) for domain configuration

---

**Last Updated**: 2024