# Upgrading Nginx from HTTP to HTTPS

This guide provides step-by-step instructions for upgrading your Nginx reverse proxy configuration from HTTP to HTTPS using Let's Encrypt SSL certificates.

## 📋 Prerequisites & Conditions

### Required Conditions

Before upgrading to HTTPS, ensure the following conditions are met:

1. **Domain Names Configured**
   - ✅ Domain names must be pointing to your server's public IP address
   - ✅ DNS records must be properly configured (A record for IPv4)
   - ✅ Domains must be accessible from the internet (not just localhost)
   - ✅ For DuckDNS: Domains must be registered and updated with your IP

2. **Server Access**
   - ✅ Root or sudo access to the server
   - ✅ SSH access to the server
   - ✅ Nginx installed and running

3. **Network Configuration**
   - ✅ Port 80 (HTTP) must be open and accessible
   - ✅ Port 443 (HTTPS) must be open and accessible
   - ✅ Firewall configured to allow HTTP/HTTPS traffic

4. **Backend Services**
   - ✅ Backend services (API and Chat) must be running
   - ✅ Services accessible on localhost:3000 and localhost:3001
   - ✅ Services configured to accept connections from Nginx

5. **Nginx Configuration**
   - ✅ Nginx configuration files exist and are working for HTTP
   - ✅ Nginx has write access to certificate directories
   - ✅ Nginx can bind to ports 80 and 443

### Optional but Recommended

- ✅ Email address for Let's Encrypt notifications
- ✅ Backup of current Nginx configuration
- ✅ Monitoring/logging setup for SSL certificate expiration

## 🚀 Step-by-Step Upgrade Process

### Step 1: Install Certbot

Certbot is the official Let's Encrypt client for obtaining and managing SSL certificates.

```bash
# Update package list
sudo apt update

# Install Certbot and Nginx plugin
sudo apt install certbot python3-certbot-nginx -y

# Verify installation
certbot --version
```

**Expected Output:**
```
certbot 2.x.x
```

### Step 2: Backup Current Configuration

**⚠️ IMPORTANT: Always backup before making changes!**

```bash
# Create backup directory
sudo mkdir -p /etc/nginx/backup

# Backup current Nginx configuration
sudo cp -r /etc/nginx/sites-available/* /etc/nginx/backup/
sudo cp /etc/nginx/nginx.conf /etc/nginx/backup/nginx.conf.backup

# Verify backup
ls -la /etc/nginx/backup/
```

### Step 3: Verify Domain Accessibility

Before obtaining certificates, verify that your domains are accessible:

```bash
# Test domain resolution
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org

# Test HTTP accessibility (should return 200 or 301)
curl -I http://exam-app-api.duckdns.org/health
curl -I http://backend-chat.duckdns.org/health
```

**Expected Results:**
- DNS should resolve to your server's IP
- HTTP requests should return status 200 or 301

### Step 4: Obtain SSL Certificates

#### Option A: Automatic Configuration (Recommended)

Certbot can automatically configure Nginx for HTTPS:

```bash
# For API service
sudo certbot --nginx -d exam-app-api.duckdns.org

# For Chat service
sudo certbot --nginx -d backend-chat.duckdns.org
```

**During the process, Certbot will:**
1. Ask for your email address (for renewal notifications)
2. Ask to agree to Terms of Service
3. Ask if you want to share email with EFF (optional)
4. Ask if you want to redirect HTTP to HTTPS (recommended: Yes)

**Expected Output:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

#### Option B: Manual Certificate Only

If you prefer to configure Nginx manually:

```bash
# Obtain certificates only (no Nginx configuration)
sudo certbot certonly --nginx -d exam-app-api.duckdns.org
sudo certbot certonly --nginx -d backend-chat.duckdns.org
```

### Step 5: Verify Certificate Installation

```bash
# Check certificate status
sudo certbot certificates

# Expected output shows:
# - Certificate paths
# - Expiration dates
# - Domains covered
```

**Expected Output:**
```
Found the following certificates:
  Certificate Name: exam-app-api.duckdns.org
    Domains: exam-app-api.duckdns.org
    Expiry Date: YYYY-MM-DD HH:MM:SS+00:00 (VALID: XX days)
    Certificate Path: /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

### Step 6: Manual Configuration (If Using Option B)

If you used Option B, manually update your Nginx configuration files.

#### API Service Configuration

**File:** `/etc/nginx/sites-available/exam-app-api.duckdns.org`

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name exam-app-api.duckdns.org;
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl http2;
    server_name exam-app-api.duckdns.org;

    # SSL Certificate paths
    ssl_certificate /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem;
    
    # SSL Configuration (Modern, secure settings)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/exam-app-api-access.log;
    error_log /var/log/nginx/exam-app-api-error.log;

    # Proxy to Docker container
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### Chat Service Configuration

**File:** `/etc/nginx/sites-available/backend-chat.duckdns.org`

```nginx
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name backend-chat.duckdns.org;
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl http2;
    server_name backend-chat.duckdns.org;

    # SSL Certificate paths
    ssl_certificate /etc/letsencrypt/live/backend-chat.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/backend-chat.duckdns.org/privkey.pem;
    
    # SSL Configuration (Modern, secure settings)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/backend-chat-access.log;
    error_log /var/log/nginx/backend-chat-error.log;

    # Proxy to Docker container (Socket.io support)
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # WebSocket support for Socket.io
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Socket.io specific settings
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts for long-lived connections (7 days for Socket.io)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
    
    # Explicit Socket.io endpoint (optional, but recommended)
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

### Step 7: Test Nginx Configuration

```bash
# Test configuration syntax
sudo nginx -t

# Expected output:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**If errors occur:**
- Check certificate paths are correct
- Verify file permissions
- Check for syntax errors in configuration

### Step 8: Reload Nginx

```bash
# Reload Nginx to apply changes
sudo systemctl reload nginx

# Verify Nginx is running
sudo systemctl status nginx
```

**Expected Status:**
```
● nginx.service - A high performance web server and a reverse proxy server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: active (running) since ...
```

### Step 9: Configure Firewall

```bash
# Allow HTTPS traffic (if not already allowed)
sudo ufw allow 443/tcp

# Verify firewall rules
sudo ufw status
```

**Expected Output:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

### Step 10: Test HTTPS

```bash
# Test API service HTTPS
curl https://exam-app-api.duckdns.org/health

# Test Chat service HTTPS
curl https://backend-chat.duckdns.org/health

# Test HTTP to HTTPS redirect
curl -I http://exam-app-api.duckdns.org/health
# Should return: HTTP/1.1 301 Moved Permanently
```

**Expected Results:**
- HTTPS requests return status 200
- HTTP requests redirect to HTTPS (301)
- SSL certificate is valid (no warnings)

### Step 11: Configure Auto-Renewal

Let's Encrypt certificates expire every 90 days. Certbot sets up automatic renewal:

```bash
# Check renewal timer status
sudo systemctl status certbot.timer

# Test renewal (dry run)
sudo certbot renew --dry-run

# Expected output:
# The dry run was successful.
```

**Manual Renewal (if needed):**
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## 🔧 Post-Upgrade Configuration

### Update Flutter App Configuration

Update your Flutter app to use HTTPS URLs:

**File:** `lib/config/api_config.dart`

```dart
// Change from HTTP to HTTPS
static const String baseUrl = 'https://exam-app-api.duckdns.org';
static const String chatBaseUrl = 'https://backend-chat.duckdns.org';
```

**File:** `lib/services/api_discovery_service.dart`

Update the default URLs to use HTTPS:

```dart
static const List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',  // HTTPS first
  'http://exam-app-api.duckdns.org',    // HTTP fallback
  // ... other URLs
];
```

### Update Backend CORS Configuration

Update your backend services to allow HTTPS origins:

**File:** `backend-api/.env` and `backend-chat/.env`

```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
```

**Note:** Keep HTTP origins for backward compatibility during transition.

## 🐛 Troubleshooting

### Issue: Certificate Not Found

**Error:**
```
nginx: [emerg] SSL_CTX_use_certificate_file("/etc/letsencrypt/live/...") failed
```

**Solution:**
```bash
# Verify certificate exists
sudo ls -la /etc/letsencrypt/live/exam-app-api.duckdns.org/

# Check file permissions
sudo chmod 644 /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
sudo chmod 600 /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

### Issue: 502 Bad Gateway

**Error:**
```
502 Bad Gateway
```

**Solution:**
```bash
# Verify backend services are running
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Verify proxy_pass URLs are correct
sudo nginx -t
```

### Issue: SSL Certificate Expired

**Error:**
```
NET::ERR_CERT_DATE_INVALID
```

**Solution:**
```bash
# Renew certificates
sudo certbot renew

# Reload Nginx
sudo systemctl reload nginx

# Verify renewal
sudo certbot certificates
```

### Issue: Mixed Content Warnings

**Error:**
```
Mixed Content: The page was loaded over HTTPS, but requested an insecure resource
```

**Solution:**
- Ensure all API calls use HTTPS URLs
- Update Flutter app configuration
- Check backend CORS settings

### Issue: WebSocket Connection Failed

**Error:**
```
WebSocket connection to 'wss://...' failed
```

**Solution:**
- Verify Socket.io is configured for HTTPS
- Check Nginx WebSocket proxy settings
- Ensure `X-Forwarded-Proto` header is set correctly

## 📊 Verification Checklist

After upgrading to HTTPS, verify the following:

- [ ] HTTPS is accessible: `curl https://exam-app-api.duckdns.org/health`
- [ ] HTTP redirects to HTTPS: `curl -I http://exam-app-api.duckdns.org/health`
- [ ] SSL certificate is valid (no browser warnings)
- [ ] Backend services respond correctly
- [ ] WebSocket connections work (for chat service)
- [ ] Flutter app can connect via HTTPS
- [ ] Auto-renewal is configured: `sudo certbot renew --dry-run`
- [ ] Firewall allows port 443
- [ ] Nginx logs show no SSL errors

## 🔒 Security Best Practices

1. **Use Strong SSL Configuration**
   - TLS 1.2+ only
   - Modern cipher suites
   - HSTS enabled

2. **Regular Certificate Monitoring**
   - Monitor certificate expiration
   - Set up renewal notifications
   - Test renewal process regularly

3. **Keep Certbot Updated**
   ```bash
   sudo apt update
   sudo apt upgrade certbot
   ```

4. **Monitor Nginx Logs**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   sudo tail -f /var/log/nginx/access.log
   ```

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot User Guide](https://eff-certbot.readthedocs.io/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - Test your SSL configuration

## ⚠️ Important Notes

1. **Certificate Expiration**: Let's Encrypt certificates expire every 90 days. Auto-renewal should handle this, but monitor it.

2. **Rate Limits**: Let's Encrypt has rate limits:
   - 50 certificates per registered domain per week
   - 5 duplicate certificates per week

3. **Backup**: Always backup your configuration before making changes.

4. **Testing**: Test in a staging environment before production deployment.

5. **Monitoring**: Set up monitoring for certificate expiration and renewal failures.

---

**Last Updated:** 2025
**Maintained By:** Exam Management App Team - me NguyenCaoAnh XD
---