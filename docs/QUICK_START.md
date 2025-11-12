# Quick Start Guide

This guide will help you get the Exam Management App up and running quickly for local development.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: 3.2.3 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Node.js**: 18.0.0 or higher ([Download Node.js](https://nodejs.org/))
- **MongoDB**: MongoDB Atlas account (free tier available) or local MongoDB instance
- **Git**: For cloning the repository

### Verify Installations

```bash
# Check Flutter
flutter --version

# Check Node.js
node --version
npm --version

# Check Git
git --version
```

## Step 1: Clone and Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd exam_management_app
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

## Step 2: Configure MongoDB

### Option A: MongoDB Atlas (Recommended for Beginners)

1. Create a free account at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Create a new cluster (free tier M0)
3. Create a database user (username and password)
4. Whitelist your IP address (or use `0.0.0.0/0` for development)
5. Get your connection string:
   - Click "Connect" → "Connect your application"
   - Copy the connection string
   - Replace `<password>` with your database user password
   - Example: `mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority`

### Option B: Local MongoDB

1. Install MongoDB locally ([Installation Guide](https://docs.mongodb.com/manual/installation/))
2. Start MongoDB service
3. Connection string: `mongodb://localhost:27017/exam_management`

## Step 3: Configure Backend Services

### Backend API Service

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

4. **Edit `.env` file**
   ```env
   MONGODB_URI=your_mongodb_connection_string_here
   MONGODB_DB=exam_management
   PORT=3000
   NODE_ENV=development
   ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
   ```

5. **Start the service**
   ```bash
   npm start
   ```

   You should see:
   ```
   ╔══════════════════════════════════════════════════════════╗
   ║     MAIN API SERVICE - Starting...                       ║
   ╚══════════════════════════════════════════════════════════╝
   
   ✅ MongoDB connected successfully
   ✅ Server running on port 3000
   ```

### Chat Service

1. **Navigate to backend-chat directory** (from project root)
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

4. **Edit `.env` file** (use the same MongoDB URI as backend-api)
   ```env
   MONGODB_URI=your_mongodb_connection_string_here
   MONGODB_DB=exam_management
   PORT=3001
   NODE_ENV=development
   ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
   DEFAULT_ADMIN_ID=  # Optional: MongoDB ObjectId of default admin
   ```

5. **Start the service**
   ```bash
   npm start
   ```

   You should see:
   ```
   ╔══════════════════════════════════════════════════════════╗
   ║     CHAT SERVICE - Starting...                           ║
   ╚══════════════════════════════════════════════════════════╝
   
   ✅ MongoDB connected successfully
   ✅ Socket.io server initialized
   ✅ Server running on port 3001
   ```

## Step 4: Run the Flutter App

1. **Return to project root**
   ```bash
   cd ..
   ```

2. **Run the app**
   ```bash
   flutter run
   ```

   The app will:
   - Automatically discover available API endpoints
   - Try localhost first, then production domains
   - Save the working endpoint for future use

### For Android Emulator

If running on Android emulator, the app will automatically try `http://10.0.2.2:3000` and `http://10.0.2.2:3001` which map to your host machine's localhost.

## Step 5: Generate Mock Data (Optional)

To populate the database with sample data:

1. **Run the mock data generator**
   ```bash
   # Windows
   scripts\generate_mock_data_standalone.bat
   
   # Linux/Mac (if available)
   flutter pub run lib/scripts/generate_mock_data_standalone.dart
   ```

   This will:
   - Generate mock students, teachers, questions, and exams
   - Upload data to MongoDB Atlas
   - Assign exams to students
   - Create student IDs in format: 20210001, 20210002, etc.

## Step 6: Verify Everything Works

1. **Check backend services are running**
   ```bash
   # Test API service
   curl http://localhost:3000/health
   
   # Test Chat service
   curl http://localhost:3001/health
   ```

2. **Launch the Flutter app**
   - The app should automatically connect to the backend
   - Check the console for API discovery logs
   - Login with a test account (if mock data was generated)

## Troubleshooting

### Backend Services Won't Start

- **Check MongoDB connection**: Verify your `MONGODB_URI` in `.env` files
- **Check ports**: Ensure ports 3000 and 3001 are not in use
- **Check Node.js version**: Requires Node.js 18.0.0 or higher
- **Check .env file**: Make sure `.env` file exists and has correct format

### Flutter App Can't Connect

- **Check backend services**: Ensure both services are running
- **Check API discovery logs**: Look for connection attempts in console
- **For Android emulator**: Use `10.0.2.2` instead of `localhost` (handled automatically)
- **Check CORS**: Ensure `ALLOWED_ORIGINS` includes your client origin

### Chat Not Working

- **Verify Socket.io connection**: Check browser/Flutter console for WebSocket errors
- **Check chat service**: Ensure backend-chat is running on port 3001
- **Check CORS**: Ensure chat service allows your origin

## Next Steps

- Read [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed backend configuration
- Read [AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md) for API auto-discovery configuration
- Read [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment guide
- Read [CHAT_IMPLEMENTATION.md](CHAT_IMPLEMENTATION.md) for chat service details

## Development Tips

- **Hot Reload**: Use `r` in Flutter terminal for hot reload
- **Restart Backend**: Restart backend services after changing `.env` files
- **Check Logs**: Both backend services output detailed logs for debugging
- **Database Access**: Use MongoDB Compass or Atlas web interface to view data

---
