# Split Backend Architecture

The backend has been split into two independent services for flexible deployment.

## Services

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

### 2. Chat Service (`backend-chat/`)
- **Database**: Supabase (PostgreSQL)
- **Port**: 3001
- **Purpose**: Real-time chat messaging
- **Endpoints**:
  - `/api/chat/*` - All chat-related endpoints
  - Uses Supabase Realtime for real-time updates

## Quick Start

### Main API (MongoDB)

```bash
cd backend-api
npm install
# Create .env with MONGODB_URI
npm start
```

### Chat Service (Supabase)

```bash
cd backend-chat
npm install
# Create .env with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
npm start
```

## Docker Deployment

Deploy both services together:

```bash
docker-compose up -d
```

## Separate Hosting

- **Main API**: Can run on Raspberry Pi with MongoDB
- **Chat Service**: Can run on cloud/server with Supabase

See `DEPLOYMENT.md` for detailed instructions.

## Flutter App Configuration

Update `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://your-api-server:3000';  // Main API
static const String chatBaseUrl = 'http://your-chat-server:3001';  // Chat service
```

## Benefits

1. **Independent Scaling**: Scale chat service separately from main API
2. **Flexible Hosting**: Main API on Pi, chat on cloud
3. **Technology Choice**: MongoDB for main data, Supabase for real-time chat
4. **Isolation**: Chat issues don't affect main API
5. **Easy Updates**: Update services independently

