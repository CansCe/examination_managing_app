// Load environment variables FIRST using dotenv/config
// This must be the first import to ensure env vars are available before other imports
import 'dotenv/config';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Verify .env file exists
const envPath = join(__dirname, '.env');
if (!existsSync(envPath)) {
  console.error(`✗ .env file not found at: ${envPath}`);
  console.error('Please create a .env file with your MongoDB connection string');
  process.exit(1);
}

// Verify MONGODB_URI is loaded
if (!process.env.MONGODB_URI) {
  console.error('✗ MONGODB_URI not found in environment variables');
  console.error('Make sure .env file contains: MONGODB_URI=your_connection_string');
  process.exit(1);
}

console.log('✓ Environment variables loaded');
console.log('✓ MONGODB_URI is configured');

// Now import other modules
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { connectDatabase } from './config/database.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';

// Import routes
import authRoutes from './routes/auth.routes.js';
import examRoutes from './routes/exam.routes.js';
import studentRoutes from './routes/student.routes.js';
import teacherRoutes from './routes/teacher.routes.js';
import questionRoutes from './routes/question.routes.js';
import examResultRoutes from './routes/examResult.routes.js';
import chatRoutes from './routes/chat.routes.js';
import { setupChatSocket } from './sockets/chat.socket.js';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS 
      ? process.env.ALLOWED_ORIGINS.split(',')
      : ['http://localhost:8080', 'http://localhost:3000'],
    credentials: true,
    methods: ['GET', 'POST']
  }
});
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());

// CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:8080', 'http://localhost:3000'];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or curl requests)
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

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const db = await connectDatabase();
    await db.admin().ping();
    res.json({ 
      ok: true, 
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development'
    });
  } catch (e) {
    res.status(500).json({ 
      ok: false, 
      error: String(e),
      timestamp: new Date().toISOString()
    });
  }
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/exams', examRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/teachers', teacherRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/exam-results', examResultRoutes);
app.use('/api/chat', chatRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Exam Management API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      exams: '/api/exams',
      students: '/api/students',
      teachers: '/api/teachers',
      questions: '/api/questions',
      examResults: '/api/exam-results',
      chat: '/api/chat'
    }
  });
});

// Error handling middleware (must be last)
app.use(notFound);
app.use(errorHandler);

// Start server
async function startServer() {
  try {
    // Connect to database
    await connectDatabase();
    console.log('✓ Database connected');

    // Setup WebSocket handlers
    setupChatSocket(io);
    
    // Start listening
    httpServer.listen(PORT, () => {
      console.log(`✓ Server running on http://localhost:${PORT}`);
      console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✓ API available at http://localhost:${PORT}/api`);
      console.log(`✓ WebSocket server ready on ws://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('✗ Failed to start server:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

// Start the server
startServer();

