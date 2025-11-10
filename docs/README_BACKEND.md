# Backend Services - Quick Reference

## Service Identification

When you see errors, look for these identifiers:

### Main API Service
- **Identifier**: `MAIN API SERVICE` or `backend-api`
- **Database**: MongoDB
- **Port**: 3000
- **Config File**: `backend-api/.env`
- **Start Script**: `start-backend-api.ps1` or `start-backend-api.bat`

### Chat Service
- **Identifier**: `CHAT SERVICE` or `backend-chat`
- **Database**: Supabase
- **Port**: 3001
- **Config File**: `backend-chat/.env`
- **Start Script**: `start-backend-chat.ps1` or `start-backend-chat.bat`

## Error Messages Format

All error messages include:
- **Service name** (clearly labeled)
- **Database type**
- **Specific error details**
- **Troubleshooting steps**

Example error output:
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

## Quick Commands

### Start Services
```powershell
# Both services
.\start-all-services.ps1

# Individual
.\start-backend-api.ps1
.\start-backend-chat.ps1
```

### Check Health
```powershell
# Main API
curl http://localhost:3000/health

# Chat Service
curl http://localhost:3001/health
```

### Check Logs
Look for service identifiers in console output:
- `MAIN API SERVICE` = Main API
- `CHAT SERVICE` = Chat Service

## Configuration Files

Each service has its own `.env` file:

- `backend-api/.env` → MongoDB configuration
- `backend-chat/.env` → Supabase configuration

**Never mix configurations!** Each service needs its own `.env` file.

## Troubleshooting

1. **Identify the service** from error message
2. **Check the correct `.env` file** for that service
3. **Verify required variables** are set
4. **Check service-specific troubleshooting** in error message

See `BACKEND_SETUP.md` for detailed setup instructions.

