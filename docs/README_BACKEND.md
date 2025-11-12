# Backend Services - Quick Reference

## Service Identification

The backend consists of two independent services:

### Main API Service
- **Identifier**: `MAIN API SERVICE` or `backend-api`
- **Database**: MongoDB
- **Port**: 3000
- **Config File**: `backend-api/.env`
- **Purpose**: Core exam management (exams, students, teachers, questions, results)

### Chat Service
- **Identifier**: `CHAT SERVICE` or `backend-chat`
- **Database**: MongoDB (same database as API service)
- **Port**: 3001
- **Config File**: `backend-chat/.env`
- **Purpose**: Real-time chat messaging via WebSocket

## Quick Commands

### Start Services

**Local Development:**
```bash
# Backend API
cd backend-api
npm install
npm start

# Chat Service
cd backend-chat
npm install
npm start
```

**Docker:**
```bash
docker-compose up -d
```

### Check Health

```bash
# Main API
curl http://localhost:3000/health

# Chat Service
curl http://localhost:3001/health
```

### View Logs

**Docker:**
```bash
docker-compose logs -f
docker-compose logs -f api
docker-compose logs -f chat
```

**PM2 (Production):**
```bash
pm2 logs
pm2 logs exam-api
pm2 logs exam-chat
```

## Configuration Files

Each service has its own `.env` file:

### Backend API (`backend-api/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
```

### Chat Service (`backend-chat/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

**Note:** Both services can use the same MongoDB database and connection string.

## Error Messages

Error messages include clear service identification:

```
╔══════════════════════════════════════════════════════════╗
║  ✗ MAIN API SERVICE - Configuration Error               ║
╚══════════════════════════════════════════════════════════╝

✗ Service: MAIN API (backend-api)
✗ Database: MongoDB
✗ Error: MONGODB_URI not found

📝 Solution:
   Add MONGODB_URI=your_connection_string to backend-api/.env
```

## Troubleshooting

1. **Identify the service** from error message
2. **Check the correct `.env` file** for that service
3. **Verify required variables** are set
4. **Check MongoDB connection** (both services use MongoDB)
5. **Verify ports** are not in use (3000 for API, 3001 for chat)

## API Endpoints

### Main API Service (Port 3000)
- `GET /health` - Health check
- `POST /api/auth/login` - Authentication
- `GET /api/exams` - List exams
- `GET /api/students` - List students
- `GET /api/teachers` - List teachers
- `GET /api/questions` - List questions
- `GET /api/exam-results` - List exam results

### Chat Service (Port 3001)
- `GET /health` - Health check
- `GET /api/chat/conversations/:userId` - Get conversations
- `GET /api/chat/messages/:conversationId` - Get messages
- WebSocket: `ws://localhost:3001` - Real-time messaging
---