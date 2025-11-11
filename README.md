# Exam Management App

A comprehensive exam management application with Flutter frontend and Node.js backend services.

## Features

- Student, Teacher, and Admin roles
- Exam creation and management
- Real-time chat system
- Question bank management
- Exam results tracking

## How the Code Works

### Architecture Overview

The application follows a client-server architecture with three main components:

1. **Flutter Mobile App (Frontend)**
   - Cross-platform mobile application built with Flutter/Dart
   - Communicates with backend services via REST API and WebSocket
   - Supports automatic API endpoint discovery
   - Handles authentication, exam management, and real-time chat

2. **Backend API Service (Node.js/Express)**
   - Main REST API service running on port 3000
   - Handles exam, student, teacher, and question management
   - Uses MongoDB for data persistence
   - Provides CRUD operations for all entities

3. **Backend Chat Service (Node.js/Express + Socket.io)**
   - Real-time chat service running on port 3001
   - Uses MongoDB for message storage
   - Implements WebSocket connections via Socket.io for live messaging
   - Handles message broadcasting to connected clients

### Real-Time Chat System

The chat system uses a hybrid approach:

1. **Message Sending**: Messages are sent via REST API to the chat service
2. **Message Storage**: Messages are saved to MongoDB
3. **Real-Time Broadcasting**: Socket.io immediately broadcasts the message to all clients in the conversation room
4. **Message Reception**: Clients receive messages via WebSocket events and update the UI instantly

**Flow:**
- User sends message → REST API endpoint → Save to MongoDB → Broadcast via Socket.io → All connected clients receive message → UI updates immediately

**Room Management:**
- Each conversation has a unique room ID (created by sorting user IDs)
- Both sender and receiver join the same room when opening chat
- Messages are broadcast to all clients in that room
- Supports both students and teachers chatting with admins

### Database Operations

All CRUD operations update MongoDB immediately:

- **Exams**: Create, update, delete exams. Deletion also cleans up student assignments
- **Students**: Create, update, delete students. Supports both studentId and rollNumber fields
- **Questions**: Create, update, delete questions
- **Chat Messages**: All messages are persisted to MongoDB with timestamps and read status

### Security Features

- Input sanitization to prevent NoSQL injection
- Rate limiting on API endpoints
- CORS configuration for allowed origins
- User role validation
- Environment variables for sensitive data (not copied into Docker images)

## How the Server is Hosted

### Local Development

The application runs locally using Docker Compose:

1. **Docker Compose Setup**
   - `docker-compose.yml` orchestrates all services
   - Services run in separate containers but share the same network
   - Environment variables are loaded from `.env` files on the host (not copied into images)
   - Ports are mapped to localhost for local access

2. **Services**
   - Backend API: `localhost:3000`
   - Backend Chat: `localhost:3001`
   - MongoDB: Internal container (not exposed externally)

3. **Configuration**
   - Copy `ENV_EXAMPLE.txt` to `.env` files in each backend directory
   - Set `MONGODB_URI` to your MongoDB connection string
   - Services automatically load environment variables at runtime

### Production Deployment

For production, the application can be deployed to a dedicated server:

1. **Server Requirements**
   - Linux server (Ubuntu recommended)
   - Docker and Docker Compose installed
   - Public IP address or domain name
   - MongoDB (can be hosted on the same server or external service)

2. **Deployment Options**

   **Option A: Direct Docker Deployment**
   - Deploy `docker-compose.yml` to server
   - Configure environment variables
   - Expose ports 3000 and 3001
   - Use firewall rules to restrict access

   **Option B: Nginx Reverse Proxy (Recommended)**
   - Install Nginx on the server
   - Configure reverse proxy to forward requests to Docker containers
   - Set up SSL certificates (Let's Encrypt)
   - Use domain names (DuckDNS or custom domains)
   - Containers run on internal ports, Nginx handles external traffic

3. **Domain Setup**
   - Use DuckDNS for free dynamic DNS (or custom domain)
   - Point domain to server's public IP
   - Configure Nginx to route traffic:
     - `api.yourdomain.com` → Backend API (port 3000)
     - `chat.yourdomain.com` → Backend Chat (port 3001)

4. **Mobile App Configuration**
   - App uses automatic endpoint discovery
   - Can also be configured at build time with `--dart-define` flags
   - App tries multiple potential domains and uses the first that responds

### Server Hosting Providers

Common options for hosting:

- **AWS EC2**: Virtual private server with full control
- **DigitalOcean**: Simple VPS with predictable pricing
- **Vultr**: High-performance VPS with global locations
- **Linode**: Developer-friendly cloud hosting
- **Hetzner**: European provider with competitive pricing

All providers offer:
- Linux servers (Ubuntu/Debian)
- Public IP addresses
- Root access for Docker installation
- Firewall/security group configuration

### Network Architecture

```
Internet
   |
   | (HTTPS/HTTP)
   |
Nginx (Port 80/443)
   |
   | (Internal network)
   |
   +---> Backend API Container (Port 3000)
   |
   +---> Backend Chat Container (Port 3001)
   |
   +---> MongoDB (Internal, not exposed)
```

### Environment Variables

Environment variables are passed at runtime (not baked into Docker images):

- `MONGODB_URI`: MongoDB connection string
- `PORT`: Service port (3000 for API, 3001 for Chat)
- `ALLOWED_ORIGINS`: Comma-separated list of allowed CORS origins
- `DOCKER_CONTAINER`: Set to `true` when running in Docker

### Quick Start

**Local Development:**
```bash
docker-compose up -d
```

**Production Build:**
```bash
# Android
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com

# iOS
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

## Documentation

### Deployment Guides

- **[docs/DEPLOYING_SERVER.md](docs/DEPLOYING_SERVER.md)** - Complete server deployment and troubleshooting guide
- **[docs/SERVER_PROVIDERS_GUIDE.md](docs/SERVER_PROVIDERS_GUIDE.md)** - Where to get a server (DigitalOcean, Vultr, AWS, etc.)
- **[docs/AWS_EC2_DEPLOYMENT.md](docs/AWS_EC2_DEPLOYMENT.md)** - Complete AWS EC2 deployment guide
- **[docs/LAPTOP_VS_SERVER_IP.md](docs/LAPTOP_VS_SERVER_IP.md)** - Laptop IP vs Server IP - Understanding the difference
- **[docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md](docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md)** - Complete server deployment with DuckDNS domains
- **[docs/DOCKER_EXPOSE_PORTS.md](docs/DOCKER_EXPOSE_PORTS.md)** - How to expose Docker containers to public internet
- **[docs/DOCKER_EXPOSE_PUBLIC_URL.md](docs/DOCKER_EXPOSE_PUBLIC_URL.md)** - Make Docker containers accessible via public URL (Nginx)
- **[docs/DEDICATED_SERVER_DOCKER_DEPLOYMENT.md](docs/DEDICATED_SERVER_DOCKER_DEPLOYMENT.md)** - Docker on your own dedicated server/hardware
- **[docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** - Master deployment guide (Docker + DNS + Domain setup)
- **[docs/PRODUCTION_DEPLOYMENT.md](docs/PRODUCTION_DEPLOYMENT.md)** - Complete guide for deploying to a dedicated server
- **[docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)** - Local development with Docker
- **[docs/DOMAIN_SETUP_GUIDE.md](docs/DOMAIN_SETUP_GUIDE.md)** - How to get domain names and safer alternatives
- **[docs/QUICK_DOMAIN_SETUP.md](docs/QUICK_DOMAIN_SETUP.md)** - Quick 5-minute domain setup guide
- **[docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md)** - Auto-discovery API setup guide

### Other Guides

- **[docs/CHAT_IMPLEMENTATION.md](docs/CHAT_IMPLEMENTATION.md)** - Chat service documentation

## Project Structure

```
exam_management_app/
├── lib/                    # Flutter app source code
│   ├── config/            # Configuration files
│   ├── features/          # App features (pages, widgets)
│   ├── models/            # Data models
│   └── services/          # API and service classes
├── backend-api/           # Main API service (MongoDB)
├── backend-chat/          # Chat service (MongoDB + Socket.io)
├── docs/                  # Documentation files (.md)
├── docker-compose.yml     # Docker configuration
└── build-production.sh    # Production build script
```

## Configuration

The app supports **automatic API endpoint discovery**! No build-time configuration needed.

### Automatic Discovery (Recommended)

The app automatically discovers available API endpoints on first launch:
- Tries multiple potential domains
- Uses the first one that responds
- Saves it locally for future use
- Re-validates on each launch

**To add your domains:**
1. Edit `lib/services/api_discovery_service.dart`
2. Add your domain URLs to the `_defaultApiUrls` and `_defaultChatUrls` lists
3. Build the app normally (no special flags needed)

See [docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md) for detailed instructions.

### Manual Configuration (Optional)

- **Build-time:** Use `--dart-define` flags (overrides auto-discovery)
- **Runtime:** App settings allow manual configuration
- **Development:** Uses `localhost` as fallback

See `lib/config/api_config.dart` for configuration options.

## License

Not yet needed
