# Docker Deployment Guide (Local Development)

This guide explains how to run the backend services locally using Docker for development purposes.

**For production deployment to a dedicated server, see [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)**

## Quick Start

### 1. Start Docker Services

```bash
# Start both API and Chat services
docker-compose up -d

# Check status
docker ps

# View logs
docker-compose logs -f
```

### 2. Configure Flutter App

Edit `lib/config/api_config.dart` based on your platform:

**For Desktop/Web:**
```dart
static const String baseUrl = 'http://localhost:3000';
static const String chatBaseUrl = 'http://localhost:3001';
```

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:3000';
static const String chatBaseUrl = 'http://10.0.2.2:3001';
```

**For Physical Device:**
```dart
// Replace with your computer's IP (e.g., 192.168.1.100)
static const String baseUrl = 'http://192.168.1.100:3000';
static const String chatBaseUrl = 'http://192.168.1.100:3001';
```

**For Production:**
```dart
static const String baseUrl = 'https://api.yourdomain.com';
static const String chatBaseUrl = 'https://chat.yourdomain.com';
```

## How It Works

### Docker Network Architecture

```
┌─────────────────────────────────────────┐
│         Docker Network                  │
│  ┌──────────┐      ┌──────────┐         │
│  │   API    │      │   Chat   │         │
│  │ :3000    │◄────►│  :3001   │         │
│  └────┬─────┘      └────┬─────┘         │
└───────┼──────────────────┼──────────────┘
        │                  │
        │ Port Mapping     │ Port Mapping
        │ 3000:3000        │ 3001:3001
        │                  │
┌───────┴──────────────────┴──────────────┐
│         Host Machine                    │
│  ┌──────────────────────────────┐       │
│  │    Flutter App               │       │
│  │  Connects via:               │       │
│  │  - localhost:3000 (API)      │       │
│  │  - localhost:3001 (Chat)     │       │
│  └──────────────────────────────┘       │
└─────────────────────────────────────────┘
```

### Connection Flow

1. **Docker Services:**
   - `api` service runs on port 3000 inside container
   - `chat` service runs on port 3001 inside container
   - Both exposed to host via port mapping

2. **Flutter App:**
   - Connects to `baseUrl` for REST API calls
   - Connects to `chatBaseUrl` for HTTP and WebSocket (Socket.io)

3. **WebSocket:**
   - Socket.io automatically converts HTTP URL to WebSocket
   - `http://localhost:3001` → `ws://localhost:3001`
   - `https://chat.yourdomain.com` → `wss://chat.yourdomain.com`

## Platform-Specific Configuration

### Android Emulator
- Use `10.0.2.2` instead of `localhost`
- This is Android's special IP for host machine

### iOS Simulator
- Use `localhost` directly
- Works the same as desktop

### Physical Device
- Find your computer's IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
- Use that IP address in the config
- Ensure device and computer are on same network

### Production
- Use domain names with HTTPS
- Set up reverse proxy (nginx/traefik)
- Configure SSL certificates

## Troubleshooting

### "Connection refused"
1. Check Docker is running: `docker ps`
2. Check services are up: `docker-compose logs`
3. Test endpoints: `curl http://localhost:3000/health`

### Android Emulator Issues
- Always use `10.0.2.2`, never `localhost`
- Ensure Docker is running on host machine

### WebSocket Connection Fails
- Check chat service health: `curl http://localhost:3001/health`
- Verify CORS settings in docker-compose.yml
- For production, ensure reverse proxy supports WebSocket upgrades

## Environment Variables

### SECURITY: .env Files Are NOT Copied Into Docker Images

**.env files are excluded from Docker images for security.** They are loaded at runtime via `docker-compose.yml`.

### Setup Instructions

1. **Create .env files** (they are gitignored and not in the repository):

**backend-api/.env:**
```env
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
```

**backend-chat/.env:**
```env
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
DEFAULT_ADMIN_ID=optional-admin-objectid
```

2. **Copy from examples:**
```bash
# Copy example files and edit them
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit the .env files with your actual credentials
```

3. **Verify .env files are NOT in Docker image:**
```bash
# Build and check
docker-compose build
docker-compose run --rm api ls -la /app/.env  # Should fail - file doesn't exist in image
```

### How It Works

- **.dockerignore** files exclude `.env` from Docker images
- **docker-compose.yml** loads `.env` files from host at runtime
- Environment variables are injected into containers, not baked into images
- This prevents secrets from being stored in Docker images

## Docker Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build

# View logs
docker-compose logs -f api
docker-compose logs -f chat

# Check service health
curl http://localhost:3000/health
curl http://localhost:3001/health
```

## Summary

1. **Docker exposes services** on `localhost:3000` and `localhost:3001`
2. **Flutter app connects** via these URLs (or IP for physical devices)
3. **WebSocket automatically** converts HTTP to WS/WSS
4. **Update `api_config.dart`** based on your platform

For more details, see the comments in `lib/config/api_config.dart`.
