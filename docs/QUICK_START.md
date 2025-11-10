# Quick Start Guide

## Two Separate Backend Services

This project uses **two independent backend services**:

1. **Main API** (`backend-api/`) - MongoDB, Port 3000
2. **Chat Service** (`backend-chat/`) - Supabase, Port 3001

## Setup (5 Minutes)

### Step 1: Configure Main API

```powershell
cd backend-api
copy ENV_EXAMPLE.txt .env
# Edit .env and add your MONGODB_URI
```

### Step 2: Configure Chat Service

```powershell
cd backend-chat
copy ENV_EXAMPLE.txt .env
# Edit .env and add your SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
```

### Step 3: Install Dependencies

```powershell
# Main API
cd backend-api
npm install

# Chat Service
cd backend-chat
npm install
```

### Step 4: Start Services

**Option A: Start Both (Recommended)**
```powershell
.\start-all-services.ps1
```

**Option B: Start Individually**
```powershell
# Terminal 1
.\start-backend-api.ps1

# Terminal 2
.\start-backend-chat.ps1
```

## Error Identification

Each service has **clearly labeled error messages**:

### Main API Errors
- Look for: `MAIN API SERVICE` in logs
- Database: MongoDB
- Port: 3000
- Config: `backend-api/.env`

### Chat Service Errors
- Look for: `CHAT SERVICE` in logs
- Database: Supabase
- Port: 3001
- Config: `backend-chat/.env`

## Health Checks

Test if services are running:

```powershell
# Main API
curl http://localhost:3000/health

# Chat Service
curl http://localhost:3001/health
```

## Common Issues

### "Service not found" Error
- Check the correct `.env` file exists
- Verify all required variables are set
- Look at the error message - it tells you which service

### Port Already in Use
- Main API uses port 3000
- Chat Service uses port 3001
- Change ports in respective `.env` files if needed

### Database Connection Failed
- **Main API**: Check `MONGODB_URI` in `backend-api/.env`
- **Chat Service**: Check `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in `backend-chat/.env`

## Next Steps

1. ✅ Both services running
2. ✅ Health checks pass
3. ✅ Start Flutter app
4. ✅ Test functionality

See `BACKEND_SETUP.md` for detailed documentation.

