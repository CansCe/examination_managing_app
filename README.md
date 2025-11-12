# Exam Management App

A comprehensive exam management application built with Flutter (frontend) and Node.js/Express (backend), featuring role-based access control, real-time chat, and MongoDB database integration.

## 🎯 Features

### Core Functionality
- **Multi-Role System**: Student, Teacher, and Admin roles with distinct permissions
- **Exam Management**: Create, edit, delete, and assign exams to students
- **Question Bank**: Manage a centralized question bank with multiple question types
- **Exam Taking**: Students can take exams with timer, auto-submission, and answer tracking
- **Results Tracking**: View and manage exam results with detailed analytics
- **Real-Time Chat**: WebSocket-based chat system for student-teacher communication

### User Experience
- **Automatic API Discovery**: App automatically finds and connects to available backend services
- **Horizontal Scrolling**: Upcoming exams displayed in a draggable, fade-effect horizontal list
- **Responsive Design**: Optimized for mobile devices with smooth animations
- **Offline Support**: Local data caching with SharedPreferences

## 🏗️ Architecture

### Frontend (Flutter)
- **Framework**: Flutter 3.2.3+
- **Language**: Dart
- **State Management**: StatefulWidget with setState
- **Key Packages**:
  - `http`: REST API communication
  - `socket_io_client`: WebSocket connections for chat
  - `mongo_dart`: Direct MongoDB access (for mock data generation)
  - `shared_preferences`: Local storage for API endpoints and user preferences
  - `uuid`: Unique identifier generation

### Backend Services

#### 1. Main API Service (`backend-api`)
- **Port**: 3000
- **Technology**: Node.js + Express
- **Database**: MongoDB
- **Features**:
  - REST API for exams, students, teachers, questions, and results
  - Authentication endpoints
  - Input sanitization to prevent NoSQL injection
  - Rate limiting on all endpoints
  - CORS configuration
  - Health check endpoint

#### 2. Chat Service (`backend-chat`)
- **Port**: 3001
- **Technology**: Node.js + Express + Socket.io
- **Database**: MongoDB
- **Features**:
  - Real-time messaging via WebSocket
  - Message persistence in MongoDB
  - Room-based chat (one-on-one conversations)
  - Automatic cleanup of messages older than 30 days
  - Support for students and teachers chatting with admins

### Database
- **MongoDB**: Primary database (MongoDB Atlas or self-hosted)
- **Collections**:
  - `exams`: Exam definitions
  - `students`: Student profiles
  - `teachers`: Teacher profiles
  - `questions`: Question bank
  - `student_exams`: Exam assignments
  - `exam_results`: Exam submissions and results
  - `messages`: Chat messages
  - `conversations`: Chat conversation metadata

## 📁 Project Structure

```
exam_management_app/
├── lib/                          # Flutter app source code
│   ├── config/                   # Configuration files
│   │   ├── api_config.dart      # API endpoint configuration
│   │   ├── database_config.dart # Database connection config
│   │   └── routes.dart          # App routing configuration
│   ├── features/                 # App features (pages, widgets)
│   │   ├── admin/               # Admin-specific pages
│   │   ├── exams/               # Exam management pages
│   │   ├── questions/           # Question bank pages
│   │   ├── shared/              # Shared components
│   │   ├── home_page.dart       # Main home screen
│   │   ├── login_page.dart      # Authentication page
│   │   ├── exam_details_page.dart
│   │   └── examination_page.dart
│   ├── models/                  # Data models
│   │   ├── exam.dart
│   │   ├── student.dart
│   │   ├── teacher.dart
│   │   ├── question.dart
│   │   └── user_role.dart
│   ├── services/                # API and service classes
│   │   ├── api_service.dart     # REST API client
│   │   ├── atlas_service.dart   # MongoDB Atlas service
│   │   ├── chat_service.dart    # WebSocket chat client
│   │   ├── auth_service.dart    # Authentication service
│   │   ├── api_discovery_service.dart # Auto-discovery service
│   │   ├── api_cache_service.dart # API response caching
│   │   └── mongodb_service.dart # Direct MongoDB access
│   ├── utils/                   # Utility functions
│   └── main.dart                # App entry point
├── backend-api/                  # Main API service
│   ├── controllers/             # Request handlers
│   ├── routes/                  # API routes
│   ├── middleware/              # Express middleware
│   │   ├── rateLimiter.js      # Rate limiting
│   │   └── errorHandler.js     # Error handling
│   ├── utils/                   # Utility functions
│   │   └── inputSanitizer.js   # Input sanitization
│   ├── config/                  # Configuration
│   │   └── database.js          # MongoDB connection
│   ├── server.js                # Express server
│   ├── package.json
│   ├── Dockerfile               # Docker image configuration
│   └── ENV_EXAMPLE.txt          # Environment variables template
├── backend-chat/                 # Chat service
│   ├── controllers/             # Chat controllers
│   ├── routes/                  # Chat routes
│   ├── sockets/                  # Socket.io handlers
│   ├── scripts/                 # Utility scripts
│   │   └── cleanup-old-messages.js
│   ├── config/                  # Configuration
│   │   ├── database.js          # MongoDB connection
│   │   └── socket.js            # Socket.io setup
│   ├── server.js                # Express + Socket.io server
│   ├── package.json
│   ├── Dockerfile               # Docker image configuration
│   └── ENV_EXAMPLE.txt
├── nginx/                        # Nginx configuration files
│   ├── exam-app-api.duckdns.org.conf  # API service config
│   ├── backend-chat.duckdns.org.conf  # Chat service config
│   └── nginx.conf.fix           # Nginx main config fixes
├── scripts/                      # Utility scripts
│   └── generate_mock_data_standalone.bat
├── docs/                         # Documentation
│   ├── HTTPS_UPGRADE.md         # HTTP to HTTPS upgrade guide
│   ├── API_PERFORMANCE_OPTIMIZATION.md
│   ├── DEPLOYMENT.md
│   └── ... (other documentation)
├── docker-compose.yml            # Docker Compose configuration
└── pubspec.yaml                  # Flutter dependencies
```

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK**: 3.2.3 or higher
- **Node.js**: 18.0.0 or higher
- **MongoDB**: MongoDB Atlas account or local MongoDB instance
- **Docker** (optional): For containerized deployment

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd exam_management_app
   ```

2. **Set up Backend API**
   ```bash
   cd backend-api
   npm install
   cp ENV_EXAMPLE.txt .env
   # Edit .env and add your MONGODB_URI
   npm start
   ```

3. **Set up Chat Service**
   ```bash
   cd backend-chat
   npm install
   cp ENV_EXAMPLE.txt .env
   # Edit .env and add your MONGODB_URI (same as backend-api)
   npm start
   ```

4. **Set up Flutter App**
   ```bash
   flutter pub get
   flutter run
   ```

### Docker Setup (Recommended)

1. **Configure environment variables**
   ```bash
   # Backend API
   cd backend-api
   cp ENV_EXAMPLE.txt .env
   # Edit .env with your MongoDB URI
   
   # Chat Service
   cd backend-chat
   cp ENV_EXAMPLE.txt .env
   # Edit .env with your MongoDB URI
   ```

2. **Start services**
   ```bash
   docker-compose up -d
   ```

3. **Verify services are running**
   ```bash
   curl http://localhost:3000/health  # API service
   curl http://localhost:3001/health  # Chat service
   ```

## 📱 Mobile App Configuration

### Automatic API Discovery (Recommended)

The app automatically discovers available API endpoints on first launch:
- Tries multiple potential domains (localhost, production domains)
- Uses the first one that responds
- Saves it locally for future use
- Re-validates on each launch

**To add your domains:**
1. Edit `lib/services/api_discovery_service.dart`
2. Add your domain URLs to `_defaultApiUrls` and `_defaultChatUrls` lists
3. Build the app normally (no special flags needed)

See [docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md) for detailed instructions.

### Manual Configuration (Optional)

**Build-time configuration:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

**Runtime configuration:**
- App settings allow manual API endpoint configuration
- Falls back to localhost for development

## 🔒 Security Features

### Backend Security
- **Input Sanitization**: All user inputs are sanitized to prevent NoSQL injection
- **Rate Limiting**: API endpoints are protected with rate limiting:
  - Authentication endpoints: 5 requests per 15 minutes
  - Read operations: 100 requests per 15 minutes
  - Write operations: 20 requests per 15 minutes
  - Health checks: 200 requests per 15 minutes
- **CORS**: Configured to allow only specified origins
- **Helmet**: Security headers middleware
- **Environment Variables**: Sensitive data (MongoDB URI) stored in `.env` files, not in code
- **HTTPS/SSL**: Support for HTTPS with Let's Encrypt SSL certificates (see [HTTPS_UPGRADE.md](docs/HTTPS_UPGRADE.md))

### Frontend Security
- **API Discovery**: Validates endpoints before connecting
- **Error Handling**: Graceful error handling for network failures
- **Input Validation**: Client-side validation before API calls

## 🗄️ Database Schema

### Exams Collection
```javascript
{
  _id: ObjectId,
  title: String,
  description: String,
  subject: String,
  difficulty: String,
  examDate: Date,
  examTime: String,
  duration: Number, // minutes
  maxStudents: Number,
  questions: [ObjectId], // References to questions collection
  createdBy: ObjectId, // Teacher/Admin ID
  createdAt: Date,
  updatedAt: Date,
  status: String
}
```

### Students Collection
```javascript
{
  _id: ObjectId,
  studentId: String, // Format: 20210001, 20210002, etc.
  rollNumber: String,
  name: String,
  email: String,
  className: String,
  assignedExams: [ObjectId], // Exam IDs
  createdAt: Date,
  updatedAt: Date
}
```

### Questions Collection
```javascript
{
  _id: ObjectId,
  questionText: String,
  type: String, // 'multiple_choice', 'true_false', 'short_answer'
  options: [String], // For multiple choice
  correctAnswer: String,
  points: Number,
  subject: String,
  difficulty: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Messages Collection
```javascript
{
  _id: ObjectId,
  conversationId: String,
  senderId: ObjectId,
  receiverId: ObjectId,
  message: String,
  timestamp: Date,
  read: Boolean,
  createdAt: Date
}
```

## 📚 Documentation

### Getting Started
- **[docs/QUICK_START.md](docs/QUICK_START.md)** - Quick setup guide for local development
- **[docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md)** - Detailed backend setup instructions
- **[docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md)** - API auto-discovery configuration

### Deployment
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Complete deployment guide
- **[docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)** - Docker deployment guide
- **[docs/PRODUCTION_DEPLOYMENT.md](docs/PRODUCTION_DEPLOYMENT.md)** - Production server deployment
- **[docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md](docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md)** - Deployment with domain names
- **[docs/HTTPS_UPGRADE.md](docs/HTTPS_UPGRADE.md)** - Upgrade Nginx from HTTP to HTTPS with SSL certificates

### Features
- **[docs/CHAT_IMPLEMENTATION.md](docs/CHAT_IMPLEMENTATION.md)** - Chat service documentation
- **[docs/CHAT_SERVICE_USAGE.md](docs/CHAT_SERVICE_USAGE.md)** - How to use the chat service

## 🛠️ Development

### Running Tests
```bash
flutter test
```

### Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

### Generating Mock Data
```bash
# Windows
scripts\generate_mock_data_standalone.bat

# The script will:
# 1. Generate mock students, teachers, questions, and exams
# 2. Upload data to MongoDB Atlas
# 3. Assign exams to students
```

## 🔧 Configuration

### Environment Variables

#### Backend API (`backend-api/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

#### Chat Service (`backend-chat/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

## 🐛 Troubleshooting

### Backend Services Not Starting
- Check MongoDB connection string in `.env` files
- Verify ports 3000 and 3001 are not in use
- Check Node.js version (requires 18.0.0+)

### Mobile App Can't Connect
- Verify backend services are running
- Check API discovery service logs
- Ensure CORS is configured correctly
- For Android emulator, use `10.0.2.2` instead of `localhost`
- If using HTTPS, verify SSL certificates are valid and not expired

### Chat Not Working
- Verify Socket.io connection in browser console
- Check WebSocket support in network configuration
- Ensure chat service is running on port 3001

## 📝 License

This project is private and not licensed for public use.

## 🤝 Contributing

This is a public project. For internal contributions, please follow the existing code style and submit pull requests for review.

## 📞 Support

For issues or questions:
1. Check the documentation in the `docs/` folder
2. Review error logs in backend services
3. Check Flutter app console for API discovery logs

---