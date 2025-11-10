# Docker Environment Variables Setup Guide

## Security: .env Files Are NOT Copied Into Docker Images

**.env files are excluded from Docker images for security reasons.** They are loaded at runtime via `docker-compose.yml` from the host machine.

## How It Works

### 1. .dockerignore Files

Both `backend-api/.dockerignore` and `backend-chat/.dockerignore` exclude:
- `.env` files
- `*.env` files
- `ENV_EXAMPLE.txt` files

This ensures secrets are **never** baked into Docker images.

### 2. docker-compose.yml

The `docker-compose.yml` file uses `env_file` to load environment variables from `.env` files on the **host machine** at runtime:

```yaml
services:
  api:
    env_file:
      - ./backend-api/.env  # Loaded from host, not from image
    environment:
      - PORT=3000  # Fallback if not in .env
```

### 3. Server Startup

The server code (`server.js`) detects if it's running in Docker:
- If `MONGODB_URI` is set (via docker-compose), it assumes Docker environment
- .env file check is skipped in Docker (only warns for local development)
- Environment variables are always checked (required)

## Setup Instructions

### Step 1: Create .env Files on Host

**backend-api/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
```

**backend-chat/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
DEFAULT_ADMIN_ID=optional-admin-objectid
```

### Step 2: Copy from Examples

```bash
# Copy example files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit with your credentials
nano backend-api/.env
nano backend-chat/.env
```

### Step 3: Verify .env Files Are NOT in Docker Image

```bash
# Build the images
docker-compose build

# Check that .env is NOT in the image
docker-compose run --rm api ls -la /app/.env
# Should show: ls: /app/.env: No such file or directory

# Verify environment variables are loaded at runtime
docker-compose run --rm api env | grep MONGODB_URI
# Should show: MONGODB_URI=your_connection_string
```

### Step 4: Start Services

```bash
# Start services (docker-compose loads .env files from host)
docker-compose up -d

# Check logs to verify environment variables are loaded
docker-compose logs api
docker-compose logs chat
```

## Security Benefits

1. **Secrets Not in Images:** .env files are never copied into Docker images
2. **Runtime Injection:** Environment variables are injected at container startup
3. **Easy Updates:** Change .env files on host without rebuilding images
4. **Git Safety:** .env files are gitignored and never committed

## Troubleshooting

### "MONGODB_URI not found" Error

**Cause:** .env file doesn't exist or MONGODB_URI is not set

**Solution:**
1. Verify .env file exists: `ls -la backend-api/.env`
2. Check file contents: `cat backend-api/.env`
3. Verify docker-compose loads it: `docker-compose config`

### ".env file not found" Warning (Non-Fatal)

**Cause:** Running in Docker but .env file check is running

**Solution:** This is OK if `MONGODB_URI` is set via docker-compose. The warning is for local development only.

### Environment Variables Not Loading

**Cause:** .env file syntax error or docker-compose not loading it

**Solution:**
1. Check .env file syntax (no spaces around `=`)
2. Verify docker-compose.yml has `env_file` section
3. Restart containers: `docker-compose down && docker-compose up -d`

## Best Practices

1. **Never commit .env files** to git (already in .gitignore)
2. **Use different .env files** for development and production
3. **Rotate secrets regularly** by updating .env files and restarting containers
4. **Use Docker secrets** for production (advanced)
5. **Verify .env files** are excluded from images before deploying

## Production Deployment

For production, consider:

1. **Docker Secrets** (Swarm mode)
2. **Environment variables** in container orchestrator (Kubernetes, etc.)
3. **Secret management services** (HashiCorp Vault, AWS Secrets Manager)
4. **.env files on host** (current approach - simple and secure)

The current approach (loading .env from host via docker-compose) is secure for most production deployments.

