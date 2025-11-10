# Deployment Guide

This guide explains how to deploy the split backend services.

## Architecture

The backend is split into two independent services:

1. **Main API Service** (`backend-api/`)
   - Uses MongoDB
   - Handles: Auth, Exams, Students, Teachers, Questions, Exam Results
   - Port: 3000
   - Can be hosted on Raspberry Pi or any server

2. **Chat Service** (`backend-chat/`)
   - Uses Supabase
   - Handles: Real-time chat messaging
   - Port: 3001
   - Can be hosted separately (cloud, Docker, etc.)

## Deployment Options

### Option 1: Docker Compose (Recommended)

Deploy both services together using Docker Compose.

#### Prerequisites
- Docker and Docker Compose installed
- MongoDB connection string
- Supabase credentials

#### Steps

1. Create environment files:

**`backend-api/.env`**:
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

**`backend-chat/.env`**:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

2. Build and start services:
```bash
docker-compose up -d
```

3. Check status:
```bash
docker-compose ps
docker-compose logs -f
```

### Option 2: Separate Hosting

#### Main API on Raspberry Pi

1. SSH into your Raspberry Pi
2. Install Node.js 18+:
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

3. Clone repository and navigate to `backend-api/`

4. Install dependencies:
```bash
npm install
```

5. Create `.env` file with MongoDB connection

6. Start service:
```bash
# Using PM2 for process management
npm install -g pm2
pm2 start server.js --name exam-api
pm2 save
pm2 startup
```

#### Chat Service on Cloud/Server

1. Deploy to your cloud provider (AWS, DigitalOcean, etc.)

2. Install Node.js and dependencies:
```bash
cd backend-chat
npm install
```

3. Create `.env` file with Supabase credentials

4. Start service:
```bash
# Using PM2
pm2 start server.js --name exam-chat
pm2 save
```

### Option 3: Windows Hosting

Both services can run on Windows.

#### Main API

1. Install Node.js from [nodejs.org](https://nodejs.org)

2. Open PowerShell in `backend-api/`:
```powershell
npm install
# Create .env file
npm start
```

#### Chat Service

1. Open PowerShell in `backend-chat/`:
```powershell
npm install
# Create .env file
npm start
```

## Environment Variables

### Main API (`backend-api/.env`)
```env
MONGODB_URI=mongodb+srv://...
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
SHUTDOWN_TOKEN=your-secret-token  # Optional, for dev
```

### Chat Service (`backend-chat/.env`)
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
DEFAULT_ADMIN_ID=uuid-here  # Optional
SHUTDOWN_TOKEN=your-secret-token  # Optional, for dev
```

## Flutter App Configuration

Update your Flutter app to use separate URLs:

**`lib/config/api_config.dart`**:
```dart
class ApiConfig {
  static const String baseUrl = 'http://your-api-server:3000';  // Main API
  static const String chatBaseUrl = 'http://your-chat-server:3001';  // Chat service
}
```

**`lib/config/supabase_config.dart`**:
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key';
}
```

## Health Checks

- Main API: `http://your-server:3000/health`
- Chat Service: `http://your-server:3001/health`

## Monitoring

### Using PM2

```bash
# View logs
pm2 logs

# Monitor
pm2 monit

# Restart services
pm2 restart exam-api
pm2 restart exam-chat
```

### Using Docker

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart api
docker-compose restart chat
```

## Troubleshooting

### Services not connecting
- Check firewall rules (ports 3000, 3001)
- Verify environment variables
- Check service logs

### MongoDB connection issues
- Verify MongoDB URI is correct
- Check network connectivity
- Ensure MongoDB allows connections from your IP

### Supabase connection issues
- Verify Supabase URL and service role key
- Check Supabase dashboard for API status
- Ensure Realtime is enabled for `chat_messages` table

## Production Tips

1. Use reverse proxy (Nginx) for SSL/TLS
2. Set up process managers (PM2) for auto-restart
3. Configure log rotation
4. Set up monitoring and alerts
5. Use environment-specific configurations
6. Enable rate limiting
7. Set up backup strategies

