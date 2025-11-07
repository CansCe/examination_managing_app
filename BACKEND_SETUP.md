# Backend Services Setup Guide

This project has **two separate backend services** that run independently.

## Services Overview

### 1. Main API Service (`backend-api/`)
- **Database**: MongoDB
- **Port**: 3000
- **Purpose**: Core exam management (auth, exams, students, teachers, questions, results)
- **Configuration**: `backend-api/.env`

### 2. Chat Service (`backend-chat/`)
- **Database**: Supabase (PostgreSQL)
- **Port**: 3001
- **Purpose**: Real-time chat messaging
- **Configuration**: `backend-chat/.env`

## Quick Start

### Option 1: Start Both Services (Windows)

```powershell
.\start-all-services.ps1
```

This will start both services in separate PowerShell windows.

### Option 2: Start Services Individually

**Main API:**
```powershell
.\start-backend-api.ps1
# or
cd backend-api
npm start
```

**Chat Service:**
```powershell
.\start-backend-chat.ps1
# or
cd backend-chat
npm start
```

### Option 3: Using Batch Files

```cmd
start-backend-api.bat
start-backend-chat.bat
```

## Configuration

### Main API Service (`backend-api/.env`)

1. Copy `ENV_EXAMPLE.txt` to `.env`:
   ```powershell
   cd backend-api
   copy ENV_EXAMPLE.txt .env
   ```

2. Edit `.env` and add your MongoDB connection:
   ```env
   MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
   MONGODB_DB=exam_management
   PORT=3000
   ```

### Chat Service (`backend-chat/.env`)

1. Copy `ENV_EXAMPLE.txt` to `.env`:
   ```powershell
   cd backend-chat
   copy ENV_EXAMPLE.txt .env
   ```

2. Edit `.env` and add your Supabase credentials:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   PORT=3001
   ```

## Error Identification

Each service has **distinct error messages** to help you identify which service has issues:

### Main API Service Errors
- Look for: `MAIN API SERVICE` in error messages
- Color: Cyan/Blue
- Database: MongoDB
- Port: 3000

### Chat Service Errors
- Look for: `CHAT SERVICE` in error messages
- Color: Magenta/Purple
- Database: Supabase
- Port: 3001

## Common Issues

### "Service not found" or Connection Errors

**Main API:**
- Check `backend-api/.env` exists
- Verify `MONGODB_URI` is correct
- Ensure MongoDB is accessible
- Check port 3000 is not in use

**Chat Service:**
- Check `backend-chat/.env` exists
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
- Ensure Supabase project is active
- Check port 3001 is not in use

### Port Already in Use

If you see "port already in use" errors:

**Main API (port 3000):**
```powershell
# Find process using port 3000
netstat -ano | findstr :3000
# Kill the process (replace PID)
taskkill /PID <PID> /F
```

**Chat Service (port 3001):**
```powershell
# Find process using port 3001
netstat -ano | findstr :3001
# Kill the process (replace PID)
taskkill /PID <PID> /F
```

Or change the port in the respective `.env` file.

## Health Checks

Test if services are running:

**Main API:**
```powershell
curl http://localhost:3000/health
```

**Chat Service:**
```powershell
curl http://localhost:3001/health
```

## Development Workflow

1. **Start Main API** in one terminal
2. **Start Chat Service** in another terminal
3. **Run Flutter app** - it will connect to both services

## Docker Deployment

See `docker-compose.yml` for running both services together:

```bash
docker-compose up -d
```

## Troubleshooting

### Service Won't Start

1. Check `.env` file exists in the service directory
2. Verify all required environment variables are set
3. Check for syntax errors in `.env` file
4. Ensure dependencies are installed: `npm install`
5. Check the service-specific error messages (they're clearly labeled)

### Database Connection Issues

**MongoDB (Main API):**
- Verify connection string format
- Check network access to MongoDB
- Ensure database name is correct

**Supabase (Chat Service):**
- Verify project URL is correct
- Check service role key (not anon key)
- Ensure Realtime is enabled for `chat_messages` table

## Service Status

Each service displays its status on startup:

```
╔══════════════════════════════════════════════════════════╗
║     MAIN API SERVICE - Running                          ║
╚══════════════════════════════════════════════════════════╝
```

or

```
╔══════════════════════════════════════════════════════════╗
║     CHAT SERVICE - Running                             ║
╚══════════════════════════════════════════════════════════╝
```

This makes it easy to identify which service is running and which has errors.

