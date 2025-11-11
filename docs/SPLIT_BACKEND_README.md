# Split Backend Architecture

The backend has been split into two independent services for flexible deployment and scalability.

## Services Overview

### 1. Main API Service (`backend-api/`)
- **Database**: MongoDB
- **Port**: 3000
- **Purpose**: Core exam management functionality
- **Endpoints**:
  - `/api/auth` - Authentication
  - `/api/exams` - Exam management
  - `/api/students` - Student management
  - `/api/teachers` - Teacher management
  - `/api/questions` - Question bank
  - `/api/exam-results` - Exam results
- **Features**:
  - REST API
  - Input sanitization
  - Rate limiting
  - CORS support

### 2. Chat Service (`backend-chat/`)
- **Database**: MongoDB (same database as API service)
- **Port**: 3001
- **Purpose**: Real-time chat messaging
- **Endpoints**:
  - `/api/chat/conversations/:userId` - Get conversations
  - `/api/chat/messages/:conversationId` - Get messages
  - WebSocket: Real-time messaging via Socket.io
- **Features**:
  - WebSocket support (Socket.io)
  - Message persistence
  - Automatic message cleanup (30 days)
  - Real-time message delivery

## Quick Start

### Main API Service

```bash
cd backend-api
npm install
cp ENV_EXAMPLE.txt .env
# Edit .env with MONGODB_URI
npm start
```

### Chat Service

```bash
cd backend-chat
npm install
cp ENV_EXAMPLE.txt .env
# Edit .env with MONGODB_URI (same as API service)
npm start
```

## Docker Deployment

Deploy both services together:

```bash
# Configure .env files
cd backend-api && cp ENV_EXAMPLE.txt .env
cd ../backend-chat && cp ENV_EXAMPLE.txt .env

# Start services
docker-compose up -d

# Verify
curl http://localhost:3000/health
curl http://localhost:3001/health
```

## Separate Hosting

Both services can be hosted separately:

- **Main API**: Can run on any server with Node.js
- **Chat Service**: Can run on any server with Node.js
- **Database**: Both services can share the same MongoDB instance

## Flutter App Configuration

The Flutter app uses auto-discovery to find available endpoints. Update `lib/services/api_discovery_service.dart` to add your domains:

```dart
static final List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',
  'http://exam-app-api.duckdns.org',
];

static final List<String> _defaultChatUrls = [
  'https://backend-chat.duckdns.org',
  'http://backend-chat.duckdns.org',
];
```

## Benefits

1. **Independent Scaling**: Scale chat service separately from main API
2. **Flexible Hosting**: Host services on different servers if needed
3. **Technology Consistency**: Both services use MongoDB
4. **Isolation**: Chat issues don't affect main API
5. **Easy Updates**: Update services independently
6. **Resource Optimization**: Allocate resources based on service needs

## Architecture Diagram

```
┌─────────────────┐         ┌─────────────────┐
│   Flutter App   │         │   Flutter App   │
│                 │         │                 │
│  Auto-Discovery │         │  Auto-Discovery │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │                           │
    ┌────▼─────┐              ┌─────▼─────┐
    │   API    │              │   Chat    │
    │ Service  │              │ Service   │
    │ :3000    │              │ :3001     │
    └────┬─────┘              └─────┬─────┘
         │                          │
         │                          │
         └──────────┬───────────────┘
                    │
              ┌─────▼─────┐
              │  MongoDB  │
              │  Database │
              └───────────┘
```

## Configuration

Both services use MongoDB. They can share the same database or use separate databases:

**Shared Database (Recommended):**
```env
# backend-api/.env
MONGODB_URI=mongodb+srv://.../exam_management
MONGODB_DB=exam_management

# backend-chat/.env
MONGODB_URI=mongodb+srv://.../exam_management
MONGODB_DB=exam_management
```

**Separate Databases:**
```env
# backend-api/.env
MONGODB_URI=mongodb+srv://.../exam_management
MONGODB_DB=exam_management

# backend-chat/.env
MONGODB_URI=mongodb+srv://.../exam_management_chat
MONGODB_DB=exam_management_chat
```

## Next Steps

- Read [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed setup
- Read [DEPLOYMENT.md](DEPLOYMENT.md) for deployment guide
- Read [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for Docker setup

---

**Last Updated**: 2024