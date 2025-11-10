# Making Docker Containers Accessible via Public URL (Not Localhost)

This guide explains how to make your Docker containers (backend-api and backend-chat) accessible via public URLs (like your DuckDNS domains) instead of just localhost.

## The Problem

By default, Docker containers are only accessible on `localhost` (127.0.0.1). To make them accessible via public URLs like:
- `https://exam-app-api.duckdns.org`
- `https://backend-chat.duckdns.org`

You need to:
1. Use Nginx as a reverse proxy
2. Configure DNS to point to your server
3. Open ports 80/443 on your firewall
4. Update environment variables
5. Setup SSL certificates

---

## Solution: Nginx Reverse Proxy

### Architecture

```
Internet → Your Server (ports 80/443) → Nginx → Docker Containers (ports 3000/3001 internal)
```

- **Nginx** handles external requests on ports 80/443 (accessible from internet)
- **Docker containers** run internally on ports 3000/3001 (not exposed to internet)
- **Nginx** proxies requests from domain names to Docker containers

---

## Step 1: Update Docker Compose for Public Access

### Option A: Use Production Docker Compose (Recommended)

Use `docker-compose.production.yml` which uses `expose` instead of `ports`:

```yaml
services:
  api:
    expose:
      - "3000"  # Internal only - Nginx will proxy
  chat:
    expose:
      - "3001"  # Internal only - Nginx will proxy
```

### Option B: Modify docker-compose.yml

Change `ports` to `expose` in `docker-compose.yml`:

```yaml
services:
  api:
    # Remove this:
    # ports:
    #   - "3000:3000"
    
    # Add this:
    expose:
      - "3000"
  
  chat:
    # Remove this:
    # ports:
    #   - "3001:3001"
    
    # Add this:
    expose:
      - "3001"
```

**Why?** 
- `ports` exposes containers directly to the internet (security risk)
- `expose` makes containers accessible only internally (via Nginx)

---

## Step 2: Install and Configure Nginx

This step installs Nginx (a web server and reverse proxy) and configures it to forward requests from your domain names to your Docker containers.

**Important Note:** This guide is primarily for Linux servers (Ubuntu/Debian) where you would deploy your Docker containers. However, if you're testing on Windows, see the [Windows-specific instructions](#windows-installation) below.

### What is Nginx?

**Nginx** is a web server that acts as a reverse proxy. It:
- Listens on ports 80 (HTTP) and 443 (HTTPS) for incoming requests
- Receives requests for your domain names (e.g., `exam-app-api.duckdns.org`)
- Forwards those requests to your Docker containers running on ports 3000/3001
- Returns the response back to the client

**Why use Nginx?**
- **Security:** Containers don't need to be exposed directly to the internet
- **SSL/HTTPS:** Nginx handles SSL certificates easily
- **Domain Routing:** Multiple domains can point to different containers
- **Load Balancing:** Can distribute traffic across multiple containers (advanced)

### 2.1 Install Nginx

```bash
# Update package list
sudo apt update

# Install Nginx
sudo apt install nginx -y

# Start Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Check if Nginx is running
sudo systemctl status nginx
```

**Expected Output:**
```
● nginx.service - A high performance web server and a reverse proxy server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: active (running) since ...
```

**If Nginx is not running:**
```bash
# Check for errors
sudo journalctl -u nginx -n 50

# Try starting again
sudo systemctl start nginx
```

### 2.2 Understand Nginx Configuration Structure

Nginx uses two directories for configuration:

- **`/etc/nginx/sites-available/`** - Stores all available site configurations
- **`/etc/nginx/sites-enabled/`** - Contains symbolic links to enabled sites

**How it works:**
1. Create configuration files in `sites-available/`
2. Create symbolic links in `sites-enabled/` to enable sites
3. Nginx only loads configurations from `sites-enabled/`

**Why this structure?**
- Easy to enable/disable sites without deleting files
- Keep multiple configurations without all being active
- Clean separation between available and active sites

### 2.3 Create Nginx Configuration for API

Create the configuration file for your API service:

```bash
# Create the configuration file
sudo nano /etc/nginx/sites-available/exam-app-api.duckdns.org
```

**Or use the provided file from your repository:**
```bash
# Copy from your repository (if you have nginx/ folder)
sudo cp nginx/exam-app-api.duckdns.org.conf /etc/nginx/sites-available/exam-app-api.duckdns.org
```

**Configuration Explanation:**

```nginx
server {
    # Listen on port 80 (HTTP) for incoming requests
    listen 80;
    
    # This configuration applies to requests for this domain
    server_name exam-app-api.duckdns.org;

    # Logging - Store access and error logs
    access_log /var/log/nginx/exam-app-api-access.log;
    error_log /var/log/nginx/exam-app-api-error.log;

    # Handle all requests (location / means "all paths")
    location / {
        # Forward requests to your Docker container running on port 3000
        proxy_pass http://localhost:3000;
        
        # Use HTTP/1.1 protocol
        proxy_http_version 1.1;
        
        # Forward upgrade requests (for WebSocket, though not needed for API)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Forward the original host header (important for virtual hosting)
        proxy_set_header Host $host;
        
        # Forward the client's real IP address
        proxy_set_header X-Real-IP $remote_addr;
        
        # Forward the client's IP through proxy chain
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Forward the protocol (http/https)
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Don't cache upgraded connections
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;  # Time to establish connection
        proxy_send_timeout 60s;     # Time to send request
        proxy_read_timeout 60s;     # Time to read response
    }
}
```

**Key Configuration Options Explained:**

1. **`listen 80;`** - Nginx listens on port 80 (HTTP). After SSL setup, Certbot will add `listen 443 ssl;`

2. **`server_name exam-app-api.duckdns.org;`** - This configuration only applies to requests for this domain

3. **`proxy_pass http://localhost:3000;`** - Forwards requests to your Docker container. `localhost:3000` works because:
   - Nginx runs on the same server as Docker
   - Containers are accessible via `localhost` from the host
   - Port 3000 is where your API container is running

4. **`proxy_set_header`** - Forwards important headers to the container:
   - `Host` - Original domain name
   - `X-Real-IP` - Client's real IP address
   - `X-Forwarded-For` - IP address chain through proxies
   - `X-Forwarded-Proto` - Original protocol (http/https)

5. **Timeouts** - Control how long Nginx waits for responses from containers

### 2.4 Create Nginx Configuration for Chat

Create the configuration file for your Chat service:

```bash
# Create the configuration file
sudo nano /etc/nginx/sites-available/backend-chat.duckdns.org
```

**Or use the provided file:**
```bash
sudo cp nginx/backend-chat.duckdns.org.conf /etc/nginx/sites-available/backend-chat.duckdns.org
```

**Configuration Explanation:**

```nginx
server {
    listen 80;
    server_name backend-chat.duckdns.org;

    # Logging
    access_log /var/log/nginx/backend-chat-access.log;
    error_log /var/log/nginx/backend-chat-error.log;

    location / {
        # Forward to Chat container on port 3001
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # WebSocket support for Socket.io
        # These headers are CRITICAL for Socket.io to work
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Socket.io specific settings
        proxy_buffering off;              # Disable buffering for real-time communication
        proxy_cache_bypass $http_upgrade; # Don't cache WebSocket connections
        
        # Extended timeouts for WebSocket connections
        # Socket.io maintains long-lived connections, so we need longer timeouts
        proxy_connect_timeout 7d;  # 7 days - for persistent WebSocket connections
        proxy_send_timeout 7d;     # 7 days - for sending data
        proxy_read_timeout 7d;     # 7 days - for reading data
    }
}
```

**Why Different Settings for Chat?**

1. **WebSocket Support:** Socket.io uses WebSocket protocol, which requires:
   - `Upgrade: websocket` header
   - `Connection: upgrade` header
   - These allow HTTP connections to "upgrade" to WebSocket

2. **Long Timeouts:** WebSocket connections stay open for a long time (hours/days), so we set timeouts to 7 days instead of 60 seconds

3. **No Buffering:** `proxy_buffering off` ensures real-time messages aren't delayed by buffering

### 2.5 Enable Nginx Sites

After creating configuration files, you need to enable them:

```bash
# Create symbolic links to enable sites
# This creates a link from sites-enabled to sites-available
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Verify the links were created
ls -la /etc/nginx/sites-enabled/

# You should see:
# exam-app-api.duckdns.org -> /etc/nginx/sites-available/exam-app-api.duckdns.org
# backend-chat.duckdns.org -> /etc/nginx/sites-available/backend-chat.duckdns.org
```

**Remove Default Site (Optional but Recommended):**

The default Nginx site shows a welcome page. Remove it to avoid conflicts:

```bash
# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Or disable it by removing the symbolic link
sudo rm /etc/nginx/sites-enabled/default
```

### 2.6 Test Nginx Configuration

Before reloading Nginx, always test the configuration:

```bash
# Test Nginx configuration for syntax errors
sudo nginx -t
```

**Expected Output (Success):**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**If there are errors:**
- Check the error message - it will tell you which file and line has the problem
- Common issues:
  - Missing semicolons (`;`)
  - Typos in directives
  - Incorrect file paths
  - Missing closing braces (`}`)

**Example Error:**
```
nginx: [emerg] unexpected "}" in /etc/nginx/sites-available/exam-app-api.duckdns.org:25
nginx: configuration file /etc/nginx/nginx.conf test failed
```

**Fix:** Check line 25 for a syntax error (missing semicolon, extra brace, etc.)

### 2.7 Reload Nginx

After testing, reload Nginx to apply changes:

```bash
# Reload Nginx (graceful reload - doesn't disconnect existing connections)
sudo systemctl reload nginx

# Or restart Nginx (disconnects all connections)
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx
```

**Difference between `reload` and `restart`:**
- **`reload`** - Gracefully reloads configuration without dropping connections (preferred)
- **`restart`** - Stops and starts Nginx, dropping all connections (use if reload doesn't work)

### 2.8 Verify Nginx is Working

Test that Nginx is forwarding requests correctly:

```bash
# Test from the server itself
curl http://localhost/health
# Should forward to your API container and return health check

# Test with domain name (if DNS is configured)
curl -H "Host: exam-app-api.duckdns.org" http://localhost/health

# Check Nginx access logs
sudo tail -f /var/log/nginx/exam-app-api-access.log

# Check Nginx error logs
sudo tail -f /var/log/nginx/exam-app-api-error.log
```

### 2.9 Troubleshooting Nginx Configuration

**Problem: Nginx test fails**

```bash
# Check syntax
sudo nginx -t

# Check for common issues:
# 1. Missing semicolons
# 2. Incorrect file paths
# 3. Missing closing braces
# 4. Typos in directive names
```

**Problem: `server_names_hash_bucket_size` error**

**Error Message:**
```
nginx: [emerg] could not build server_names_hash, you should increase server_names_hash_bucket_size: 32
```

**Cause:** This happens when your domain names (like `exam-app-api.duckdns.org`) are too long for the default hash bucket size.

**Solution:** Increase the `server_names_hash_bucket_size` in the main Nginx configuration:

```bash
# Edit main Nginx configuration
sudo nano /etc/nginx/nginx.conf
```

Add or modify in the `http` block:

```nginx
http {
    # Increase hash bucket size for long domain names
    server_names_hash_bucket_size 64;  # or 128 if 64 is not enough
    
    # ... rest of configuration ...
}
```

**Complete fix:**

1. **Edit main Nginx config:**
```bash
sudo nano /etc/nginx/nginx.conf
```

2. **Find the `http` block and add:**
```nginx
http {
    # Increase hash bucket size for long domain names
    server_names_hash_bucket_size 64;
    
    # ... existing configuration ...
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

3. **Test configuration:**
```bash
sudo nginx -t
```

4. **If still getting error, increase to 128:**
```nginx
server_names_hash_bucket_size 128;
```

5. **Reload Nginx:**
```bash
sudo systemctl reload nginx
```

**Alternative: Increase `server_names_hash_max_size` (if needed):**

If you have many server blocks, you might also need to increase the max size:

```nginx
http {
    server_names_hash_bucket_size 64;
    server_names_hash_max_size 512;  # Default is 512, increase if you have many domains
    
    # ... rest of configuration ...
}
```

**Verify the fix:**
```bash
# Test configuration
sudo nginx -t

# Should see:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**Problem: Nginx starts but doesn't forward requests**

```bash
# Check if containers are running
docker ps

# Test if containers are accessible
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check if sites are enabled
ls -la /etc/nginx/sites-enabled/
```

**Problem: 502 Bad Gateway Error**

This means Nginx can't reach your Docker containers:

```bash
# Check if containers are running
docker ps

# Check if containers are listening on correct ports
sudo netstat -tulpn | grep -E '3000|3001'

# Test direct access to containers
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check Nginx error logs for details
sudo tail -f /var/log/nginx/error.log
```

**Problem: Connection Refused**

```bash
# Check if Docker containers are running
docker-compose ps

# Check if ports are exposed correctly in docker-compose.yml
# Should use 'expose' not 'ports' for internal access

# Restart containers
docker-compose restart
```

**Problem: Wrong Site Served**

```bash
# Check which sites are enabled
ls -la /etc/nginx/sites-enabled/

# Check server_name in configuration
sudo grep server_name /etc/nginx/sites-available/*

# Make sure default site is disabled
sudo rm /etc/nginx/sites-enabled/default
```

### 2.10 Understanding the Complete Flow

Here's how a request flows through the system:

```
1. User requests: https://exam-app-api.duckdns.org/api/students
   ↓
2. DNS resolves to your server IP
   ↓
3. Request arrives at your server on port 443 (HTTPS)
   ↓
4. Nginx receives the request
   ↓
5. Nginx checks server_name and matches "exam-app-api.duckdns.org"
   ↓
6. Nginx forwards request to http://localhost:3000/api/students
   ↓
7. Docker container (API) processes the request
   ↓
8. Container returns response
   ↓
9. Nginx receives response and forwards it back to user
   ↓
10. User receives response
```

### 2.11 Next Steps After Nginx Configuration

After completing Step 2, you should:

1. ✅ Nginx is installed and running
2. ✅ Configuration files are created
3. ✅ Sites are enabled
4. ✅ Nginx configuration is tested
5. ✅ Nginx is reloaded

**Next:** Proceed to Step 3 (Configure Firewall) to allow internet access to your server.

---

## Windows Installation (For Testing on Windows)

**Important:** The main deployment guide above is for Linux servers (Ubuntu/Debian), which is the recommended approach for production. However, if you need to test Nginx on Windows locally, you have two options:

### Option 1: Use WSL (Windows Subsystem for Linux) - Recommended

WSL allows you to run Linux on Windows, which is the easiest way to follow the Linux instructions.

#### Install WSL

```powershell
# Open PowerShell as Administrator
# Install WSL with Ubuntu
wsl --install

# Or install specific Ubuntu version
wsl --install -d Ubuntu-22.04

# Restart your computer when prompted
```

#### Use WSL to Install Nginx

```bash
# Open Ubuntu terminal (WSL)
# Update package list
sudo apt update

# Install Nginx (same as Linux instructions)
sudo apt install nginx -y

# Start Nginx
sudo service nginx start

# Enable Nginx on boot
sudo systemctl enable nginx
```

#### Access Nginx from Windows

- **From WSL:** `http://localhost`
- **From Windows browser:** `http://localhost`
- **From other devices on network:** `http://YOUR_WINDOWS_IP`

#### Configure Nginx in WSL

Follow the same Linux instructions above, but note:

1. **Configuration files location:** `/etc/nginx/sites-available/` (same as Linux)
2. **Access from Windows:** Use `http://localhost` to test
3. **Docker containers:** Must be accessible from WSL's `localhost`

#### Run Docker in WSL

```bash
# Install Docker in WSL (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start Docker
sudo service docker start

# Test Docker
docker ps
```

#### Access Docker Containers from WSL

If your Docker containers are running on Windows Docker Desktop:

```bash
# Get Windows host IP from WSL
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'

# Use Windows host IP instead of localhost
# Example: proxy_pass http://172.20.10.1:3000;
```

**Or use Docker Desktop WSL integration:**
1. Open Docker Desktop
2. Go to Settings → Resources → WSL Integration
3. Enable integration with your Ubuntu distribution
4. Restart WSL: `wsl --shutdown` then reopen Ubuntu

### Option 2: Install Nginx Native on Windows

You can install Nginx directly on Windows, but it's more complex and less common.

#### Download Nginx for Windows

1. **Download Nginx:**
   - Go to: https://nginx.org/en/download.html
   - Download: `nginx/Windows-X.X.X` (latest stable version)
   - Extract to: `C:\nginx\`

#### Install Nginx as Windows Service (Optional)

```powershell
# Open PowerShell as Administrator
# Install Nginx as a service using nssm (Non-Sucking Service Manager)

# Download nssm
# Go to: https://nssm.cc/download
# Extract nssm.exe to C:\nginx\

# Install Nginx as service
C:\nginx\nssm.exe install nginx "C:\nginx\nginx.exe"

# Start service
net start nginx
```

#### Configure Nginx on Windows

1. **Edit configuration file:**
   - Location: `C:\nginx\conf\nginx.conf`
   - Or create site configs in: `C:\nginx\conf\sites-available\`

2. **Create configuration files:**

Create `C:\nginx\conf\sites-available\exam-app-api.duckdns.org.conf`:

```nginx
server {
    listen 80;
    server_name exam-app-api.duckdns.org;

    access_log logs/exam-app-api-access.log;
    error_log logs/exam-app-api-error.log;

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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

Create `C:\nginx\conf\sites-available\backend-chat.duckdns.org.conf`:

```nginx
server {
    listen 80;
    server_name backend-chat.duckdns.org;

    access_log logs/backend-chat-access.log;
    error_log logs/backend-chat-error.log;

    location / {
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

3. **Include site configs in main nginx.conf:**

Edit `C:\nginx\conf\nginx.conf` and add at the end of `http` block:

```nginx
http {
    # ... existing configuration ...
    
    # Include site configurations
    include sites-available/*.conf;
}
```

4. **Create sites-available directory:**

```powershell
# Create directory
mkdir C:\nginx\conf\sites-available

# Copy configuration files to this directory
```

#### Start/Stop Nginx on Windows

```powershell
# Start Nginx
C:\nginx\nginx.exe

# Stop Nginx
C:\nginx\nginx.exe -s stop

# Reload configuration
C:\nginx\nginx.exe -s reload

# Test configuration
C:\nginx\nginx.exe -t
```

#### Windows Firewall Configuration

```powershell
# Open PowerShell as Administrator
# Allow Nginx through Windows Firewall

# Allow HTTP (port 80)
New-NetFirewallRule -DisplayName "Nginx HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Allow HTTPS (port 443)
New-NetFirewallRule -DisplayName "Nginx HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
```

### Comparison: WSL vs Native Windows

| Feature | WSL | Native Windows |
|---------|-----|----------------|
| **Ease of Setup** | Easy | Moderate |
| **Compatibility** | Full Linux compatibility | Windows-specific |
| **Package Management** | apt (Linux) | Manual download |
| **Service Management** | systemd/service | Manual/nssm |
| **Docker Integration** | Good (with WSL integration) | Docker Desktop |
| **Recommended For** | Testing, Development | Advanced users |

### Recommended Approach for Windows

**For Testing/Development:**
- ✅ Use **WSL** - Easier and more compatible with Linux instructions
- ✅ Follow the Linux instructions above in WSL
- ✅ Use Docker Desktop with WSL integration

**For Production:**
- ✅ Deploy to a **Linux server** (Ubuntu/Debian VPS)
- ✅ Use the main Linux instructions above
- ✅ Don't use Windows for production deployment

### Troubleshooting on Windows

#### WSL Issues

**Nginx not starting in WSL:**
```bash
# Check if Nginx is running
sudo service nginx status

# Start Nginx
sudo service nginx start

# Check logs
sudo tail -f /var/log/nginx/error.log
```

**Docker containers not accessible from WSL:**
```bash
# Get Windows host IP
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'

# Use Windows IP in Nginx config instead of localhost
# Example: proxy_pass http://172.20.10.1:3000;
```

#### Native Windows Issues

**Nginx not starting:**
```powershell
# Check if port 80 is already in use
netstat -ano | findstr :80

# Stop conflicting services (IIS, Apache, etc.)
# Or change Nginx port in nginx.conf
```

**Configuration not loading:**
```powershell
# Test configuration
C:\nginx\nginx.exe -t

# Check logs
type C:\nginx\logs\error.log
```

**Problem: `server_names_hash_bucket_size` error on Windows**

**Error Message:**
```
nginx: [emerg] could not build server_names_hash, you should increase server_names_hash_bucket_size: 32
```

**Solution for Windows:**

1. **Edit main Nginx configuration:**
   - Location: `C:\nginx\conf\nginx.conf`
   - Open with Notepad or any text editor

2. **Find the `http` block and add:**
```nginx
http {
    # Increase hash bucket size for long domain names
    server_names_hash_bucket_size 64;
    
    # ... existing configuration ...
}
```

3. **Test configuration:**
```powershell
C:\nginx\nginx.exe -t
```

4. **If still getting error, increase to 128:**
```nginx
server_names_hash_bucket_size 128;
```

5. **Reload Nginx:**
```powershell
C:\nginx\nginx.exe -s reload
```

**Firewall blocking:**
```powershell
# Check firewall rules
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*Nginx*"}

# Add firewall rule if missing (see Windows Firewall Configuration above)
```

### Important Notes for Windows

1. **Production Deployment:** Windows is not recommended for production. Deploy to a Linux server (Ubuntu/Debian VPS) for better performance and compatibility.

2. **Docker Desktop:** If using Docker Desktop on Windows, enable WSL integration for better compatibility.

3. **Port Conflicts:** Windows may have IIS or other services using port 80. Disable them or change Nginx port.

4. **SSL Certificates:** Certbot (for SSL) doesn't work natively on Windows. Use WSL or deploy to Linux server.

5. **File Paths:** Windows uses backslashes (`\`), but Nginx config uses forward slashes (`/`) even on Windows.

### Next Steps

- **If using WSL:** Follow the main Linux instructions above
- **If using native Windows:** Follow the Windows-specific instructions above
- **For production:** Deploy to a Linux server (see `SERVER_PROVIDERS_GUIDE.md`)

---

## Step 3: Configure Firewall

Open ports 80 (HTTP) and 443 (HTTPS) to allow internet access:

```bash
# Install UFW (if not installed)
sudo apt install ufw -y

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH (if not already allowed)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

**Important:** 
- Ports 3000 and 3001 should NOT be open to the internet
- Only ports 80 and 443 should be open (handled by Nginx)

---

## Step 4: Configure DNS (DuckDNS)

Update your DuckDNS domains to point to your server's IP address:

### Get Your Server IP

```bash
# Get your server's public IP
curl -4 ifconfig.me
```

### Update DuckDNS

```bash
# Update DuckDNS (replace YOUR_TOKEN with your DuckDNS token)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_DUCKDNS_TOKEN&ip=YOUR_SERVER_IP"
```

Or update manually at https://www.duckdns.org

### Verify DNS Resolution

```bash
# Check if domains resolve to your server IP
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org
```

**Expected Output (Example):**
```
Server:  UnKnown
Address:  fd00:db80::1

Non-authoritative answer:
Name:    backend-chat.duckdns.org
Address:  117.5.56.77
```

**What this means:**
- ✅ **DNS is working correctly** - The domain resolves to your server IP (117.5.56.77 in this example)
- ✅ **DuckDNS is configured properly** - The domain is pointing to the correct IP address
- ✅ **Ready for next steps** - You can proceed with Nginx configuration and SSL setup

**If DNS is not resolving:**
- Check DuckDNS configuration at https://www.duckdns.org
- Verify your server IP address matches the DNS record
- Wait a few minutes for DNS propagation (can take up to 5 minutes)
- Try flushing DNS cache: `ipconfig /flushdns` (Windows) or `sudo systemd-resolve --flush-caches` (Linux)

---

## Step 5: Update Environment Variables

Update your `.env` files to use public URLs instead of localhost:

### backend-api/.env

```env
MONGODB_URI=your_mongodb_uri
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
# Use your public domain URLs
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
```

### backend-chat/.env

```env
MONGODB_URI=your_mongodb_uri
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
# Use your public domain URLs
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
DEFAULT_ADMIN_ID=optional-admin-objectid
```

### Restart Containers

```bash
# Restart containers to apply new environment variables
docker-compose restart

# Or if using production compose
docker-compose -f docker-compose.production.yml restart
```

---

## Step 6: Setup SSL Certificates (HTTPS)

### Install Certbot

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y
```

### Get SSL Certificates

```bash
# Get SSL certificate for API domain
sudo certbot --nginx -d exam-app-api.duckdns.org

# Get SSL certificate for Chat domain
sudo certbot --nginx -d backend-chat.duckdns.org

# Follow the prompts:
# - Enter email address
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (recommended: Yes)
```

### Update Environment Variables for HTTPS

After SSL is set up, update `.env` files to use HTTPS only:

**backend-api/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### Restart Containers

```bash
docker-compose restart
```

---

## Step 7: Verify Public Access

### Test API Endpoint

```bash
# Test from your local machine (not on server)
curl https://exam-app-api.duckdns.org/health

# Should return: {"status":"ok","service":"Main API Service"}
```

### Test Chat Endpoint

```bash
# Test from your local machine
curl https://backend-chat.duckdns.org/health

# Should return: {"status":"ok","service":"Chat Service"}
```

### Test from Browser

Open in your browser:
- `https://exam-app-api.duckdns.org/health`
- `https://backend-chat.duckdns.org/health`

You should see the health check response.

---

## Troubleshooting

### Containers Not Accessible

**Check if containers are running:**
```bash
docker ps
docker-compose logs api
docker-compose logs chat
```

**Check if containers are accessible internally:**
```bash
# On the server
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### Nginx Not Routing

**Check Nginx configuration:**
```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

**Check if Nginx can reach containers:**
```bash
# On the server
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### DNS Not Resolving

**Check DNS resolution:**
```bash
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org
```

**Expected Output (DNS working):**
```
Server:  UnKnown
Address:  fd00:db80::1

Non-authoritative answer:
Name:    backend-chat.duckdns.org
Address:  117.5.56.77
```

**If DNS is resolving correctly:**
- ✅ Domain is pointing to your server IP
- ✅ Proceed with Nginx configuration
- ✅ Verify server is accessible at that IP

**If DNS is NOT resolving:**
- Check DuckDNS configuration at https://www.duckdns.org
- Verify your server IP address
- Update DuckDNS if IP changed (see below)
- Wait for DNS propagation (can take 5-10 minutes)

**Update DuckDNS if IP changed:**
```bash
# Get your current server IP
curl -4 ifconfig.me

# Update DuckDNS
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=YOUR_SERVER_IP"

# Or automatically detect and update
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"
```

**Verify server is accessible:**
```bash
# Test if server is accessible (replace with your IP)
curl http://117.5.56.77/health

# Test if Nginx is responding
curl -I http://117.5.56.77

# Test if Docker containers are accessible
curl http://117.5.56.77:3000/health  # If ports are exposed
curl http://117.5.56.77:3001/health  # If ports are exposed
```

**Common DNS Issues:**

1. **DNS resolves but server not accessible:**
   - Check firewall rules (ports 80/443 should be open)
   - Verify Nginx is running
   - Check if Docker containers are running
   - Verify server IP is correct

2. **DNS not resolving:**
   - Check DuckDNS configuration
   - Verify domain names are correct
   - Wait for DNS propagation
   - Check if domain is active in DuckDNS

3. **Wrong IP address:**
   - Update DuckDNS with correct IP
   - Wait for DNS propagation
   - Verify server IP hasn't changed

### Firewall Blocking

**Check firewall status:**
```bash
sudo ufw status
```

**Allow ports if needed:**
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### CORS Errors

**Check ALLOWED_ORIGINS in .env files:**
```bash
cat backend-api/.env | grep ALLOWED_ORIGINS
cat backend-chat/.env | grep ALLOWED_ORIGINS
```

**Ensure domains are included:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**Restart containers after updating:**
```bash
docker-compose restart
```

### SSL Certificate Issues

**Check certificate status:**
```bash
sudo certbot certificates
```

**Renew certificates:**
```bash
sudo certbot renew
```

**Test renewal:**
```bash
sudo certbot renew --dry-run
```

---

## Security Considerations

### ✅ Do's

1. **Use Nginx reverse proxy** - Don't expose containers directly
2. **Use `expose` instead of `ports`** - Keep containers internal
3. **Open only ports 80/443** - Close ports 3000/3001
4. **Use HTTPS** - Setup SSL certificates
5. **Update ALLOWED_ORIGINS** - Use your domain URLs
6. **Configure firewall** - Only allow necessary ports

### ❌ Don'ts

1. **Don't expose ports 3000/3001 directly** - Security risk
2. **Don't use `localhost` in ALLOWED_ORIGINS** - Use domain URLs
3. **Don't skip SSL** - Always use HTTPS in production
4. **Don't leave firewall open** - Configure properly

---

## Summary

### To Make Docker Containers Accessible via Public URL:

1. ✅ **Update Docker Compose** - Use `expose` instead of `ports`
2. ✅ **Install Nginx** - Reverse proxy server
3. ✅ **Configure Nginx** - Proxy domains to containers
4. ✅ **Configure Firewall** - Open ports 80/443
5. ✅ **Configure DNS** - Point domains to server IP
6. ✅ **Update Environment Variables** - Use domain URLs in ALLOWED_ORIGINS
7. ✅ **Setup SSL** - Get HTTPS certificates
8. ✅ **Restart Containers** - Apply changes

### Architecture

```
Internet
  ↓
Your Server (ports 80/443 open)
  ↓
Nginx (reverse proxy)
  ↓
Docker Containers (ports 3000/3001 internal only)
```

### Your Public URLs

- **API:** `https://exam-app-api.duckdns.org`
- **Chat:** `https://backend-chat.duckdns.org`

---

## Quick Reference

### Files to Update

1. **docker-compose.yml** - Change `ports` to `expose`
2. **backend-api/.env** - Update `ALLOWED_ORIGINS`
3. **backend-chat/.env** - Update `ALLOWED_ORIGINS`
4. **Nginx configs** - Create proxy configurations

### Commands

```bash
# Start containers
docker-compose -f docker-compose.production.yml up -d

# Restart containers
docker-compose restart

# Check status
docker ps
curl http://localhost:3000/health

# Test public URLs
curl https://exam-app-api.duckdns.org/health
curl https://backend-chat.duckdns.org/health
```

---

## Next Steps

1. Follow the steps above to configure public access
2. Test your endpoints from a browser or external machine
3. Update your Flutter app to use the public URLs
4. Monitor logs for any issues

For complete deployment guide, see `SERVER_DEPLOYMENT_WITH_DOMAINS.md`.

