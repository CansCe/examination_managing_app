# Supabase Migration Guide

This guide explains how to migrate from MongoDB to Supabase for the Exam Management System.

## Overview

The backend has been migrated from MongoDB to Supabase, which provides:
- PostgreSQL database (scalable and relational)
- REST API (Realtime replication disabled - using polling instead)
- Auto-generated REST API
- Row Level Security (RLS)
- Edge Functions support

## Setup Instructions

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create an account
2. Create a new project
3. Note your project URL and Service Role Key (Settings > API)

### 2. Run Database Migrations

1. Open Supabase Dashboard > SQL Editor
2. Run the migration file: `backend-api/supabase/migrations/001_initial_schema.sql`
3. This creates all necessary tables, indexes, and triggers

### 3. Configure Environment Variables

Update `backend-chat/.env`:

```env
# Remove MongoDB variables
# MONGODB_URI=...
# MONGODB_DB=...

# Add Supabase variables
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Optional
DEFAULT_ADMIN_ID=uuid-of-default-admin
SHUTDOWN_TOKEN=your-shutdown-token
```

### 4. Install Dependencies

```bash
cd backend-api
npm install
```

### 5. Start the Server

**Note**: Realtime replication is disabled. The service uses REST API only. The Flutter app should use polling for real-time updates.

```bash
npm start
# or
npm run dev
```

## Key Changes

### Database Schema

- **UUIDs instead of ObjectIds**: All IDs are now UUIDs (36 characters) instead of MongoDB ObjectIds (24 characters)
- **Relational tables**: Uses proper foreign keys and junction tables
- **Timestamps**: Uses `TIMESTAMPTZ` for timezone-aware dates

### API Changes

Most API endpoints remain the same, but:
- IDs are now UUIDs (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
- Some response structures may differ slightly
- Pagination works the same way

### Real-time Chat

- **Before**: Socket.IO WebSocket connections
- **After**: REST API with polling (Realtime replication disabled)
- The Flutter app should use polling or REST API calls instead of Realtime subscriptions

## Migration Checklist

- [x] Database schema created
- [x] Backend controllers updated (auth, exam)
- [ ] Backend controllers updated (student, teacher, question, examResult)
- [x] Backend controllers updated (chat - REST API only, no Realtime)
- [ ] Flutter app updated to use polling instead of Realtime subscriptions
- [x] Chat service updated to use Supabase REST API (Realtime disabled)
- [ ] Data migration script (if migrating existing data)

## Data Migration

If you have existing MongoDB data, you'll need to:

1. Export data from MongoDB
2. Transform ObjectIds to UUIDs
3. Map MongoDB collections to PostgreSQL tables
4. Import into Supabase

A migration script can be created if needed.

## Testing

1. Test authentication: `POST /api/auth/login`
2. Test exam creation: `POST /api/exams`
3. Test chat: Messages work via REST API (polling recommended for real-time updates)
4. Verify all CRUD operations work correctly

## Troubleshooting

### "Table does not exist" error
- Run the migration SQL file in Supabase SQL Editor

### "Invalid UUID" errors
- Ensure all IDs are in UUID format (36 characters with hyphens)
- Old ObjectIds need to be converted

### Real-time updates not working
- Realtime replication is disabled - this is expected
- Use REST API polling in the Flutter app for real-time updates
- Poll the `/api/chat/conversation` endpoint periodically (e.g., every 2-3 seconds)

## Next Steps

1. Complete remaining controller migrations
2. Update Flutter app to use Supabase client
3. Test thoroughly
4. Deploy to production

