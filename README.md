# Exam Management App

A comprehensive exam management application with Flutter frontend and Node.js backend services.

## Features

- Student, Teacher, and Admin roles
- Exam creation and management
- Real-time chat system
- Question bank management
- Exam results tracking

## Quick Start

### Local Development

1. **Start Backend Services:**
   ```bash
   docker-compose up -d
   ```

2. **Configure Environment:**
   - Copy `backend-api/ENV_EXAMPLE.txt` to `backend-api/.env`
   - Copy `backend-chat/ENV_EXAMPLE.txt` to `backend-chat/.env`
   - Fill in MongoDB connection details

3. **Run Flutter App:**
   ```bash
   flutter run
   ```

### Production Deployment

For deploying to a dedicated server and building the mobile app:

**See [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) for complete guide.**

**Quick Build:**
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

Or use the build scripts:
```bash
# Linux/Mac
./build-production.sh android https://api.yourdomain.com https://chat.yourdomain.com

# Windows
.\build-production.ps1 android https://api.yourdomain.com https://chat.yourdomain.com
```

## Documentation

### 🚀 Deployment Guides

- **[SERVER_PROVIDERS_GUIDE.md](SERVER_PROVIDERS_GUIDE.md)** - **Where to get a server** (DigitalOcean, Vultr, AWS, etc.) ⭐
- **[AWS_EC2_DEPLOYMENT.md](AWS_EC2_DEPLOYMENT.md)** - **Complete AWS EC2 deployment guide** ⭐
- **[LAPTOP_VS_SERVER_IP.md](LAPTOP_VS_SERVER_IP.md)** - **Laptop IP vs Server IP - Understanding the difference** ⭐
- **[SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md)** - **Complete server deployment with DuckDNS domains** ⭐
- **[DOCKER_EXPOSE_PORTS.md](DOCKER_EXPOSE_PORTS.md)** - **How to expose Docker containers to public internet** ⭐
- **[DOCKER_EXPOSE_PUBLIC_URL.md](DOCKER_EXPOSE_PUBLIC_URL.md)** - Make Docker containers accessible via public URL (Nginx)
- **[DEDICATED_SERVER_DOCKER_DEPLOYMENT.md](DEDICATED_SERVER_DOCKER_DEPLOYMENT.md)** - Docker on your own dedicated server/hardware
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - **Master deployment guide** (Docker + DNS + Domain setup)
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Complete guide for deploying to a dedicated server
- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Local development with Docker
- **[DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)** - How to get domain names and safer alternatives
- **[QUICK_DOMAIN_SETUP.md](QUICK_DOMAIN_SETUP.md)** - Quick 5-minute domain setup guide
- **[AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md)** - Auto-discovery API setup guide

### 📚 Other Guides

- **[CHAT_IMPLEMENTATION.md](CHAT_IMPLEMENTATION.md)** - Chat service documentation

## Project Structure

```
exam_management_app/
├── lib/                    # Flutter app source code
│   ├── config/            # Configuration files
│   ├── features/          # App features (pages, widgets)
│   ├── models/            # Data models
│   └── services/          # API and service classes
├── backend-api/           # Main API service (MongoDB)
├── backend-chat/          # Chat service (MongoDB + Socket.io)
├── docker-compose.yml     # Docker configuration
└── build-production.sh    # Production build script
```

## Configuration

The app supports **automatic API endpoint discovery**! No build-time configuration needed.

### Automatic Discovery (Recommended)

The app automatically discovers available API endpoints on first launch:
- Tries multiple potential domains
- Uses the first one that responds
- Saves it locally for future use
- Re-validates on each launch

**To add your domains:**
1. Edit `lib/services/api_discovery_service.dart`
2. Add your domain URLs to the `_defaultApiUrls` and `_defaultChatUrls` lists
3. Build the app normally (no special flags needed)

See [AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md) for detailed instructions.

### Manual Configuration (Optional)

- **Build-time:** Use `--dart-define` flags (overrides auto-discovery)
- **Runtime:** App settings allow manual configuration
- **Development:** Uses `localhost` as fallback

See `lib/config/api_config.dart` for configuration options.

## License

Not yet needed
