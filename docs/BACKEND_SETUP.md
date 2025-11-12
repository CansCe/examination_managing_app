# Backend Setup Guide

This guide provides detailed instructions for setting up and configuring the backend services for the Exam Management App.

## Architecture Overview

The backend consists of two separate services:

1. **Main API Service** (`backend-api`): REST API for exams, students, teachers, questions, and results
2. **Chat Service** (`backend-chat`): WebSocket-based real-time chat service

Both services use MongoDB as the database and can share the same database instance.

## Prerequisites

- Node.js 18.0.0 or higher
- MongoDB Atlas account or local MongoDB instance
- npm or yarn package manager

## Main API Service Setup

### Directory Structure

```
backend-api/
├── config/
│   └── database.js          # MongoDB connection
├── controllers/              # Request handlers
│   ├── auth.controller.js
│   ├── exam.controller.js
│   ├── examResult.controller.js
│   ├── question.controller.js
│   ├── student.controller.js
│   └── teacher.controller.js
├── middleware/
│   ├── errorHandler.js      # Error handling middleware
│   └── rateLimiter.js       # Rate limiting middleware
├── routes/                   # API routes
│   ├── auth.routes.js
│   ├── exam.routes.js
│   ├── examResult.routes.js
│   ├── question.routes.js
│   ├── student.routes.js
│   └── teacher.routes.js
├── utils/
│   └── inputSanitizer.js    # Input sanitization utilities
├── server.js                 # Express server
├── package.json
└── ENV_EXAMPLE.txt          # Environment variables template
```

### Installation

1. **Navigate to backend-api directory**
   ```bash
   cd backend-api
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Create environment file**
   ```bash
   # Windows
   copy ENV_EXAMPLE.txt .env
   
   # Linux/Mac
   cp ENV_EXAMPLE.txt .env
   ```

### Environment Variables

Edit `.env` file with your configuration:

```env
# MongoDB Connection String
# Format: mongodb+srv://username:password@cluster.mongodb.net/database?retryWrites=true&w=majority
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management

# Server Configuration
PORT=3000
NODE_ENV=development

# CORS Configuration (comma-separated origins)
# For local development:
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
# For production, add your domains:
# ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org

# Optional: Shutdown token for development
# SHUTDOWN_TOKEN=your-secret-token
```

### Starting the Service

```bash
npm start
```

The service will:
- Connect to MongoDB
- Start Express server on port 3000
- Initialize rate limiting middleware
- Set up CORS
- Register all API routes

### API Endpoints

- **Health Check**: `GET /health`
- **Authentication**: `POST /api/auth/login`
- **Exams**: `GET /api/exams`, `POST /api/exams`, etc.
- **Students**: `GET /api/students`, `POST /api/students`, etc.
- **Teachers**: `GET /api/teachers`, `POST /api/teachers`, etc.
- **Questions**: `GET /api/questions`, `POST /api/questions`, etc.
- **Results**: `GET /api/exam-results`, `POST /api/exam-results`, etc.

## Chat Service Setup

### Directory Structure

```
backend-chat/
├── config/
│   ├── database.js          # MongoDB connection
│   └── socket.js            # Socket.io configuration
├── controllers/
│   └── chat.controller.js   # Chat request handlers
├── routes/
│   └── chat.routes.js        # Chat HTTP routes
├── scripts/
│   └── cleanup-old-messages.js  # Message cleanup script
├── middleware/
│   ├── errorHandler.js      # Error handling middleware
│   └── rateLimiter.js       # Rate limiting middleware
├── utils/
│   └── supabase-helpers.js  # Utility functions (legacy)
├── server.js                # Express + Socket.io server
├── package.json
└── ENV_EXAMPLE.txt          # Environment variables template
```

### Installation

1. **Navigate to backend-chat directory**
   ```bash
   cd backend-chat
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Create environment file**
   ```bash
   # Windows
   copy ENV_EXAMPLE.txt .env
   
   # Linux/Mac
   cp ENV_EXAMPLE.txt .env
   ```

### Environment Variables

Edit `.env` file with your configuration:

```env
# MongoDB Connection URI (same as backend-api)
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management

# Optional: Default Admin ID (MongoDB ObjectId format)
# DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011

# Server Configuration
PORT=3001
NODE_ENV=development

# CORS Configuration (comma-separated origins)
# For local development:
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
# For production, add your domains:
# ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org

# Optional: Shutdown token for development
# SHUTDOWN_TOKEN=your-secret-token
```

### Starting the Service

```bash
npm start
```

The service will:
- Connect to MongoDB
- Initialize Socket.io server
- Start Express server on port 3001
- Set up WebSocket event handlers
- Register chat routes

### Chat Endpoints

- **Health Check**: `GET /health`
- **Get Conversations**: `GET /api/chat/conversations/:userId`
- **Get Messages**: `GET /api/chat/messages/:conversationId`
- **WebSocket**: Connect to `ws://localhost:3001` (or your domain)

## Security Features

### Rate Limiting

Both services implement rate limiting to prevent abuse:

- **Authentication endpoints**: 5 requests per 15 minutes
- **Read operations**: 100 requests per 15 minutes
- **Write operations**: 20 requests per 15 minutes
- **Health checks**: 200 requests per 15 minutes

### Input Sanitization

All user inputs are sanitized to prevent NoSQL injection:

- String inputs are sanitized
- ObjectId inputs are validated
- Query parameters are sanitized
- Username and password inputs are validated

### CORS Configuration

CORS is configured to allow only specified origins. Update `ALLOWED_ORIGINS` in `.env` files to include your client domains.

## Database Collections

Both services use the following MongoDB collections:

- `exams`: Exam definitions
- `students`: Student profiles
- `teachers`: Teacher profiles
- `questions`: Question bank
- `student_exams`: Exam assignments (junction table)
- `exam_results`: Exam submissions and results
- `messages`: Chat messages (chat service only)
- `conversations`: Chat conversation metadata (chat service only)

## Running Both Services

### Option 1: Separate Terminals

Open two terminals:

**Terminal 1 (API Service):**
```bash
cd backend-api
npm start
```

**Terminal 2 (Chat Service):**
```bash
cd backend-chat
npm start
```

### Option 2: Docker Compose

See [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) for Docker setup.

## Troubleshooting

### MongoDB Connection Issues

- **Check connection string**: Verify `MONGODB_URI` is correct
- **Check network**: Ensure MongoDB Atlas IP whitelist includes your IP
- **Check credentials**: Verify username and password are correct
- **Check database name**: Ensure database exists or can be created

### Port Already in Use

- **Change port**: Update `PORT` in `.env` file
- **Kill process**: Find and kill process using the port
  ```bash
  # Windows
  netstat -ano | findstr :3000
  taskkill /PID <pid> /F
  
  # Linux/Mac
  lsof -ti:3000 | xargs kill
  ```

### Service Won't Start

- **Check Node.js version**: Requires Node.js 18.0.0+
- **Check dependencies**: Run `npm install` again
- **Check .env file**: Ensure `.env` file exists and is properly formatted
- **Check logs**: Look for error messages in console output

## Production Considerations

- Use environment variables for all sensitive data
- Enable HTTPS in production
- Configure proper CORS origins
- Set up monitoring and logging
- Use process manager (PM2) for production
- Set up automatic message cleanup (chat service)
- Configure rate limiting appropriately for production load
