# Backend Services Comparison

## Quick Reference

| Feature | Main API Service | Chat Service |
|---------|-----------------|--------------|
| **Folder** | `backend-api/` | `backend-chat/` |
| **Database** | MongoDB | MongoDB |
| **Port** | 3000 | 3001 |
| **Config File** | `backend-api/.env` | `backend-chat/.env` |
| **Protocol** | HTTP REST | HTTP REST + WebSocket |
| **Error Identifier** | `MAIN API SERVICE` | `CHAT SERVICE` |
| **Health Check** | `http://localhost:3000/health` | `http://localhost:3001/health` |

## Configuration Files

### Main API (`backend-api/.env`)
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

## Error Identification

### Main API Errors
```
╔══════════════════════════════════════════════════════════╗
║  ✗ MAIN API SERVICE - Configuration Error               ║
╚══════════════════════════════════════════════════════════╝
✗ Service: MAIN API (backend-api)
✗ Database: MongoDB
✗ Error: MONGODB_URI not found
```

### Chat Service Errors
```
╔══════════════════════════════════════════════════════════╗
║  ✗ CHAT SERVICE - Configuration Error                     ║
╚══════════════════════════════════════════════════════════╝
✗ Service: CHAT SERVICE (backend-chat)
✗ Database: MongoDB
✗ Error: MONGODB_URI not found
```

## Startup Messages

### Main API Startup
```
╔══════════════════════════════════════════════════════════╗
║     MAIN API SERVICE - Starting...                       ║
╚══════════════════════════════════════════════════════════╝

✅ MongoDB connected successfully
✅ Server running on port 3000
```

### Chat Service Startup
```
╔══════════════════════════════════════════════════════════╗
║     CHAT SERVICE - Starting...                           ║
╚══════════════════════════════════════════════════════════╝

✅ MongoDB connected successfully
✅ Socket.io server initialized
✅ Server running on port 3001
```

## Health Check Responses

### Main API Health
```json
{
  "ok": true,
  "service": "MAIN API SERVICE",
  "database": "MongoDB",
  "port": 3000
}
```

### Chat Service Health
```json
{
  "ok": true,
  "service": "CHAT SERVICE",
  "database": "MongoDB",
  "port": 3001
}
```

## API Endpoints

### Main API Service (Port 3000)
- `GET /health` - Health check
- `POST /api/auth/login` - Authentication
- `GET /api/exams` - List exams
- `POST /api/exams` - Create exam
- `GET /api/students` - List students
- `GET /api/teachers` - List teachers
- `GET /api/questions` - List questions
- `GET /api/exam-results` - List exam results

### Chat Service (Port 3001)
- `GET /health` - Health check
- `GET /api/chat/conversations/:userId` - Get conversations
- `GET /api/chat/messages/:conversationId` - Get messages
- WebSocket: `ws://localhost:3001` - Real-time messaging

## Database Collections

### Main API Service Uses
- `exams` - Exam definitions
- `students` - Student profiles
- `teachers` - Teacher profiles
- `questions` - Question bank
- `student_exams` - Exam assignments
- `exam_results` - Exam submissions and results

### Chat Service Uses
- `messages` - Chat messages
- `conversations` - Chat conversation metadata

**Note:** Both services can share the same MongoDB database.

## Troubleshooting by Service

### Main API Issues
1. Check `backend-api/.env`
2. Verify `MONGODB_URI`
3. Test MongoDB connection
4. Check port 3000 availability
5. Verify CORS configuration

### Chat Service Issues
1. Check `backend-chat/.env`
2. Verify `MONGODB_URI`
3. Test MongoDB connection
4. Check port 3001 availability
5. Verify WebSocket support
6. Check Socket.io connection

## Quick Commands

### Start Services

**Local:**
```bash
# Main API
cd backend-api && npm start

# Chat Service
cd backend-chat && npm start
```

**Docker:**
```bash
docker-compose up -d
```

### Health Checks
```bash
curl http://localhost:3000/health  # Main API
curl http://localhost:3001/health  # Chat Service
```

### View Logs

**Docker:**
```bash
docker-compose logs -f api
docker-compose logs -f chat
```

**PM2:**
```bash
pm2 logs exam-api
pm2 logs exam-chat
```

## Differences

| Aspect | Main API | Chat Service |
|--------|----------|--------------|
| **Primary Function** | CRUD operations | Real-time messaging |
| **Communication** | REST API | REST + WebSocket |
| **Data Focus** | Exams, students, teachers | Messages, conversations |
| **Real-time** | No | Yes (Socket.io) |
| **Rate Limiting** | Yes | Yes |
| **Input Sanitization** | Yes | Yes |

## Similarities

- Both use MongoDB
- Both use Node.js + Express
- Both have rate limiting
- Both have input sanitization
- Both support CORS
- Both have health check endpoints
- Both can share the same database

---