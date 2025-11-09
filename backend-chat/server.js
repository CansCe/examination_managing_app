// Load environment variables FIRST using dotenv/config
import 'dotenv/config';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';
import { createServer } from 'http';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================
// CHAT SERVICE (MongoDB + Socket.io)
// ============================================
console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║     CHAT SERVICE - Starting...                           ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');

// Verify .env file exists
const envPath = join(__dirname, '.env');
if (!existsSync(envPath)) {
  console.error('╔══════════════════════════════════════════════════════════╗');
  console.error('║      CHAT SERVICE - Configuration Error                  ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error(`\n✗ .env file not found at: ${envPath}`);
  console.error('✗ Service: CHAT SERVICE (backend-chat)');
  console.error('✗ Database: MongoDB');
  console.error('\n📝 Solution:');
  console.error('   1. Copy ENV_EXAMPLE.txt to .env');
  console.error('   2. Fill in your MONGODB_URI');
  console.error('   3. Restart the service\n');
  process.exit(1);
}

// Verify MongoDB URI is loaded
if (!process.env.MONGODB_URI) {
  console.error('╔══════════════════════════════════════════════════════════╗');
  console.error('║     CHAT SERVICE - Configuration Error                   ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error('\n✗ MONGODB_URI not found in environment variables');
  console.error('✗ Service: CHAT SERVICE (backend-chat)');
  console.error('✗ Database: MongoDB');
  console.error('\n📝 Solution:');
  console.error('   Add MONGODB_URI to backend-chat/.env');
  console.error('   Use the same MongoDB URI as backend-api\n');
  process.exit(1);
}

console.log('✓ Environment variables loaded');
console.log('✓ Service: CHAT SERVICE (backend-chat)');
console.log('✓ Database: MongoDB');
console.log('✓ Real-time: Socket.io WebSockets');
console.log('✓ Port: ' + (process.env.PORT || 3001));

// Now import other modules
import express from 'express';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { connectDatabase, closeDatabase, getDatabase } from './config/database.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import chatRoutes from './routes/chat.routes.js';
import { setIO } from './config/socket.js';
import { healthLimiter } from './middleware/rateLimiter.js';

const app = express();
const httpServer = createServer(app);
const PORT = process.env.PORT || 3001;

// Initialize Socket.io
const io = new SocketIOServer(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS 
      ? process.env.ALLOWED_ORIGINS.split(',')
      : ['http://localhost:8080', 'http://localhost:3000', 'http://localhost:3001'],
    methods: ['GET', 'POST'],
    credentials: true
  },
  transports: ['websocket', 'polling']
});

// Security middleware
app.use(helmet());

// CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:8080', 'http://localhost:3000', 'http://localhost:3001'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV === 'development') {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Health check endpoint with rate limiting
app.get('/health', healthLimiter, async (req, res) => {
  try {
    const db = await connectDatabase();
    await db.collection('chat_messages').findOne({}, { projection: { _id: 1 } });
    res.json({ 
      ok: true,
      service: 'CHAT SERVICE',
      database: 'MongoDB',
      port: PORT,
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      api: 'REST API + Socket.io WebSockets',
      endpoints: {
        chat: '/api/chat',
        conversations: '/api/chat/conversations',
        unread: '/api/chat/unread',
        defaultAdmin: '/api/chat/default-admin',
        websocket: 'Socket.io on port ' + PORT
      }
    });
  } catch (e) {
    res.status(500).json({ 
      ok: false,
      service: 'CHAT SERVICE',
      database: 'MongoDB',
      error: String(e),
      timestamp: new Date().toISOString(),
      troubleshooting: [
        'Check MONGODB_URI in .env',
        'Verify MongoDB is accessible',
        'Check network/firewall settings',
        'Ensure MongoDB server is running'
      ]
    });
  }
});

// API routes
app.use('/api/chat', chatRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Exam Management Chat Service',
    version: '2.0.0',
    endpoints: {
      health: '/health',
      chat: '/api/chat',
      api: 'REST API + Socket.io WebSockets'
    }
  });
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`✓ Client connected: ${socket.id}`);

  // Join conversation room
  socket.on('join_conversation', ({ userId, targetUserId }) => {
    if (!userId || !targetUserId) {
      console.error(`  ✗ Invalid join_conversation: missing userId or targetUserId`);
      return;
    }
    const conversationId = [userId, targetUserId].sort().join(':');
    socket.join(conversationId);
    console.log(`  → ${socket.id} joined conversation: ${conversationId}`);
    // Acknowledge join
    socket.emit('joined_conversation', { conversationId });
  });

  // Leave conversation room
  socket.on('leave_conversation', ({ userId, targetUserId }) => {
    const conversationId = [userId, targetUserId].sort().join(':');
    socket.leave(conversationId);
    console.log(`  ← ${socket.id} left conversation: ${conversationId}`);
  });

  // Handle new message (from REST API, broadcast to room)
  socket.on('new_message', async (messageData) => {
    try {
      const { conversationId, fromUserId, toUserId } = messageData;
      if (conversationId) {
        // Broadcast to all clients in the conversation room
        io.to(conversationId).emit('message_received', messageData);
        console.log(`  📨 Message broadcasted to conversation: ${conversationId}`);
      }
    } catch (error) {
      console.error('Error broadcasting message:', error);
      socket.emit('error', { message: 'Failed to broadcast message' });
    }
  });

  // Handle typing indicator
  socket.on('typing', ({ conversationId, userId, isTyping }) => {
    socket.to(conversationId).emit('user_typing', { userId, isTyping });
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log(`✗ Client disconnected: ${socket.id}`);
  });
});

// Set io instance for use in controllers (after io is created)
setIO(io);

// Error handling middleware (must be last)
app.use(notFound);
app.use(errorHandler);

// Start server
let serverInstance;
async function startServer() {
  try {
    // Connect to database
    console.log('\n📡 Connecting to MongoDB...');
    await connectDatabase();
    console.log('✓ MongoDB connected');
    
    // Start listening
    serverInstance = httpServer.listen(PORT, () => {
      console.log('\n╔══════════════════════════════════════════════════════════╗');
      console.log('║     CHAT SERVICE - Running                               ║');
      console.log('╚══════════════════════════════════════════════════════════╝');
      console.log(`\n✓ Service: CHAT SERVICE (backend-chat)`);
      console.log(`✓ URL: http://localhost:${PORT}`);
      console.log(`✓ API: http://localhost:${PORT}/api/chat`);
      console.log(`✓ WebSocket: ws://localhost:${PORT}`);
      console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✓ Database: MongoDB`);
      console.log(`✓ Real-time: Socket.io WebSockets`);
      console.log('\n📋 Available endpoints:');
      console.log(`   - Health: http://localhost:${PORT}/health`);
      console.log(`   - Chat: http://localhost:${PORT}/api/chat`);
      console.log(`   - Conversations: http://localhost:${PORT}/api/chat/conversations`);
      console.log(`   - Unread: http://localhost:${PORT}/api/chat/unread`);
      console.log(`   - Default Admin: http://localhost:${PORT}/api/chat/default-admin`);
      console.log(`   - WebSocket: ws://localhost:${PORT}`);
      console.log('\n💡 Note: This service handles all chat functionality with real-time WebSocket support\n');
    });
  } catch (error) {
    console.error('\n╔══════════════════════════════════════════════════════════╗');
    console.error('║   CHAT SERVICE - Startup Failed                          ║');
    console.error('╚══════════════════════════════════════════════════════════╝');
    console.error('\n✗ Service: CHAT SERVICE (backend-chat)');
    console.error('✗ Error:', error.message);
    console.error('\n📝 Troubleshooting:');
    console.error('   1. Check MONGODB_URI in .env');
    console.error('   2. Verify MongoDB is accessible');
    console.error('   3. Check network/firewall settings');
    console.error('   4. Ensure MongoDB server is running');
    console.error('   5. Review error details above\n');
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  io.close();
  await closeDatabase();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT signal received: closing HTTP server');
  io.close();
  await closeDatabase();
  process.exit(0);
});

// Start the server
startServer();

// Shutdown endpoint for development
app.post('/shutdown', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ ok: false, error: 'Shutdown disabled in production' });
  }
  const token = req.headers['x-shutdown-token'];
  if (!process.env.SHUTDOWN_TOKEN || token !== process.env.SHUTDOWN_TOKEN) {
    return res.status(401).json({ ok: false, error: 'Unauthorized' });
  }
  res.json({ ok: true, message: 'Shutting down chat service' });
  try {
    serverInstance?.close(async () => {
      io.close();
      await closeDatabase();
      console.log('Chat service closed');
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 5000).unref();
  } catch (e) {
    process.exit(0);
  }
});
