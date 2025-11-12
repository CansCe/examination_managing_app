# Production Deployment Guide

This guide covers deploying the Exam Management App to a production server.

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Node.js 18.0.0+ installed
- MongoDB Atlas account or MongoDB instance
- Domain names (optional but recommended)
- SSL certificates (for HTTPS)
- Nginx installed
- PM2 or similar process manager

## Server Setup

### 1. Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Node.js

```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

### 3. Install PM2

```bash
sudo npm install -g pm2
```

### 4. Install Nginx

```bash
sudo apt install nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Application Setup

### 1. Clone Repository

```bash
cd /var/www
sudo git clone <repository-url> exam-management-app
cd exam-management-app
```

### 2. Configure Backend API

```bash
cd backend-api
npm install --production
cp ENV_EXAMPLE.txt .env
nano .env
```

Edit `.env`:
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://api.yourdomain.com,https://chat.yourdomain.com
```

### 3. Configure Chat Service

```bash
cd ../backend-chat
npm install --production
cp ENV_EXAMPLE.txt .env
nano .env
```

Edit `.env`:
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://api.yourdomain.com,https://chat.yourdomain.com
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

## Start Services with PM2

### 1. Start API Service

```bash
cd /var/www/exam-management-app/backend-api
pm2 start server.js --name exam-api
```

### 2. Start Chat Service

```bash
cd /var/www/exam-management-app/backend-chat
pm2 start server.js --name exam-chat
```

### 3. Save PM2 Configuration

```bash
pm2 save
pm2 startup
```

Follow the instructions to enable PM2 on system startup.

### 4. Monitor Services

```bash
# View status
pm2 status

# View logs
pm2 logs

# View specific service logs
pm2 logs exam-api
pm2 logs exam-chat
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
    server_name api.yourdomain.com;
    
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
    server_name chat.yourdomain.com;
    
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

### 1. Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx
```

### 2. Obtain SSL Certificates

```bash
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

### 3. Auto-Renewal

Certbot automatically sets up renewal. Test renewal:

```bash
sudo certbot renew --dry-run
```

## Firewall Configuration

### 1. Configure UFW

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 2. Verify Firewall

```bash
sudo ufw status
```

## Monitoring and Logging

### 1. PM2 Monitoring

```bash
# Install PM2 monitoring
pm2 install pm2-logrotate

# Configure log rotation
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
```

### 2. Nginx Logs

```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

### 3. Application Logs

```bash
# PM2 logs
pm2 logs exam-api
pm2 logs exam-chat

# Save logs to file
pm2 logs exam-api --lines 1000 > api.log
```

## Health Checks

### 1. Create Health Check Script

```bash
nano /var/www/exam-management-app/health-check.sh
```

```bash
#!/bin/bash

# Check API service
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "API service: OK"
else
    echo "API service: FAILED"
    pm2 restart exam-api
fi

# Check Chat service
if curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "Chat service: OK"
else
    echo "Chat service: FAILED"
    pm2 restart exam-chat
fi
```

```bash
chmod +x /var/www/exam-management-app/health-check.sh
```

### 2. Set Up Cron Job

```bash
crontab -e
```

Add:
```
*/5 * * * * /var/www/exam-management-app/health-check.sh >> /var/log/health-check.log 2>&1
```

## Backup Strategy

### 1. Database Backups

Set up MongoDB Atlas automated backups or manual backups:

```bash
# Manual backup script
nano /var/www/exam-management-app/backup-db.sh
```

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
mongodump --uri="mongodb+srv://..." --out=/backups/mongodb-$DATE
```

### 2. Configuration Backups

```bash
# Backup .env files
tar -czf /backups/config-$(date +%Y%m%d).tar.gz \
  /var/www/exam-management-app/backend-api/.env \
  /var/www/exam-management-app/backend-chat/.env
```

### 3. Code Backups

Use Git for code versioning and backups.

## Security Hardening

### 1. Keep System Updated

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Configure Fail2Ban

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. Disable Root Login

```bash
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
sudo systemctl restart sshd
```

### 4. Use Strong Passwords

- Use strong, unique passwords
- Consider SSH key authentication
- Enable two-factor authentication if possible

## Performance Optimization

### 1. Enable Gzip Compression

Add to Nginx config:

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
```

### 2. Set Resource Limits

```bash
# PM2 resource limits
pm2 start server.js --name exam-api --max-memory-restart 500M
```

### 3. Database Indexing

Ensure MongoDB collections have proper indexes:

```javascript
// Example indexes
db.exams.createIndex({ examDate: 1 });
db.messages.createIndex({ conversationId: 1, timestamp: -1 });
```

## Troubleshooting

### Services Won't Start

- Check logs: `pm2 logs`
- Verify environment variables
- Check MongoDB connection
- Verify ports are available

### Nginx Errors

- Check config: `sudo nginx -t`
- Check logs: `sudo tail -f /var/log/nginx/error.log`
- Verify upstream services are running

### SSL Certificate Issues

- Check domain DNS records
- Verify certificate expiration: `sudo certbot certificates`
- Renew certificates: `sudo certbot renew`

## Maintenance

### Update Application

```bash
cd /var/www/exam-management-app
git pull
cd backend-api && npm install --production
cd ../backend-chat && npm install --production
pm2 restart all
```

### Update Dependencies

```bash
cd backend-api
npm update
pm2 restart exam-api

cd ../backend-chat
npm update
pm2 restart exam-chat
```
---