# Backend Services Comparison

## Quick Reference

| Feature | Main API Service | Chat Service |
|---------|-----------------|--------------|
| **Folder** | `backend-api/` | `backend-chat/` |
| **Database** | MongoDB | Supabase (PostgreSQL) |
| **Port** | 3000 | 3001 |
| **Config File** | `backend-api/.env` | `backend-chat/.env` |
| **Start Script** | `start-backend-api.ps1` | `start-backend-chat.ps1` |
| **Error Identifier** | `MAIN API SERVICE` | `CHAT SERVICE` |
| **Health Check** | `http://localhost:3000/health` | `http://localhost:3001/health` |

## Configuration Files

### Main API (`backend-api/.env`)
```env
MONGODB_URI=mongodb+srv://...
MONGODB_DB=exam_management
PORT=3000
```

### Chat Service (`backend-chat/.env`)
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-key
PORT=3001
```

## Error Identification

### Main API Errors
```
╔══════════════════════════════════════════════════════════╗
║  ✗ MAIN API SERVICE - Error                           ║
╚══════════════════════════════════════════════════════════╝
✗ Service: MAIN API (backend-api)
✗ Database: MongoDB
```

### Chat Service Errors
```
╔══════════════════════════════════════════════════════════╗
║  ✗ CHAT SERVICE - Error                               ║
╚══════════════════════════════════════════════════════════╝
✗ Service: CHAT SERVICE (backend-chat)
✗ Database: Supabase
```

## Startup Messages

### Main API Startup
```
╔══════════════════════════════════════════════════════════╗
║     MAIN API SERVICE - Starting...                      ║
╚══════════════════════════════════════════════════════════╝
```

### Chat Service Startup
```
╔══════════════════════════════════════════════════════════╗
║     CHAT SERVICE - Starting...                          ║
╚══════════════════════════════════════════════════════════╝
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
  "database": "Supabase",
  "port": 3001
}
```

## Troubleshooting by Service

### Main API Issues
1. Check `backend-api/.env`
2. Verify `MONGODB_URI`
3. Test MongoDB connection
4. Check port 3000 availability

### Chat Service Issues
1. Check `backend-chat/.env`
2. Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
3. Test Supabase connection
4. Check port 3001 availability
5. Ensure Realtime is enabled

## Quick Commands

```powershell
# Start both
.\start-all-services.ps1

# Start individually
.\start-backend-api.ps1
.\start-backend-chat.ps1

# Health checks
curl http://localhost:3000/health  # Main API
curl http://localhost:3001/health  # Chat Service
```

