# Quick Start: Production Deployment

## Step 1: Deploy Backend to Server

### On Your Server:

```bash
# 1. Clone repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app

# 2. Configure environment variables
# Edit backend-api/.env and backend-chat/.env with your MongoDB URI

# 3. Start Docker services
docker-compose up -d

# 4. Verify services are running
docker ps
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### Configure Domain (Optional but Recommended):

```bash
# Setup Nginx reverse proxy
# Configure SSL with Let's Encrypt
# Your APIs will be accessible at:
# - https://api.yourdomain.com
# - https://chat.yourdomain.com
```

## Step 2: Build Mobile App

### Option A: Using Build Scripts (Recommended)

**Linux/Mac:**
```bash
./build-production.sh android https://api.yourdomain.com https://chat.yourdomain.com
```

**Windows:**
```powershell
.\build-production.ps1 android https://api.yourdomain.com https://chat.yourdomain.com
```

### Option B: Manual Build

**Android APK:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

**Android App Bundle (Play Store):**
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

## Step 3: Distribute App

### Android:
- **Play Store:** Upload the `.aab` file
- **Direct Distribution:** Share the `.apk` file

### iOS:
- Open Xcode → Archive → Distribute to App Store

## Configuration Examples

### With Domain (HTTPS):
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

### With IP Address (HTTP):
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://192.168.1.100:3000 \
  --dart-define=CHAT_BASE_URL=http://192.168.1.100:3001
```

**Note:** For production, always use HTTPS with a domain name for security.

## Testing

1. Install the APK on a device
2. Open the app
3. Try to login
4. Verify all features work
5. Test chat functionality

## Troubleshooting

### "Connection refused"
- Check if Docker services are running: `docker ps`
- Verify firewall allows connections
- Check server logs: `docker-compose logs`

### "SSL/TLS error"
- Ensure you're using HTTPS URLs
- Check SSL certificate is valid
- For development, you can use HTTP with IP address

### "CORS error"
- Update `ALLOWED_ORIGINS` in backend `.env` files
- Include your app's origin in CORS settings

## Next Steps

See [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for:
- Detailed server setup
- Reverse proxy configuration
- SSL certificate setup
- Monitoring and maintenance
- Security best practices

