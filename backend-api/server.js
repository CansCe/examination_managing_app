// Load environment variables FIRST using dotenv/config
// This must be the first import to ensure env vars are available before other imports
import 'dotenv/config';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================
// MAIN API SERVICE (MongoDB Backend)
// ============================================
console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║     MAIN API SERVICE - Starting...                       ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');

// Check if running in Docker (environment variables provided at runtime via docker-compose)
// In Docker, .env files are loaded from host via docker-compose env_file, not copied into image
const isDocker = process.env.DOCKER_CONTAINER === 'true' || 
                 process.env.MONGODB_URI !== undefined; // If MONGODB_URI is set, assume Docker or env vars provided

// Verify .env file exists (only for non-Docker/local development)
const envPath = join(__dirname, '.env');
if (!existsSync(envPath) && !isDocker) {
  console.warn('╔══════════════════════════════════════════════════════════╗');
  console.warn('║     MAIN API SERVICE - Configuration Warning             ║');
  console.warn('╚══════════════════════════════════════════════════════════╝');
  console.warn(`\n⚠ .env file not found at: ${envPath}`);
  console.warn('⚠ Service: MAIN API (backend-api)');
  console.warn('\n💡 This is OK if:');
  console.warn('   - Running in Docker (env vars provided via docker-compose)');
  console.warn('   - Environment variables are set in the system');
  console.warn('\n📝 Otherwise, create .env file:');
  console.warn('   1. Copy ENV_EXAMPLE.txt to .env');
  console.warn('   2. Fill in your MONGODB_URI');
  console.warn('   3. Restart the service\n');
}

// Verify MONGODB_URI is loaded (required in all cases)
if (!process.env.MONGODB_URI) {
  console.error('╔══════════════════════════════════════════════════════════╗');
  console.error('║     MAIN API SERVICE - Configuration Error               ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error('\n✗ MONGODB_URI not found in environment variables');
  console.error('✗ Service: MAIN API (backend-api)');
  console.error('✗ Database: MongoDB');
  console.error('\n📝 Solution:');
  if (isDocker) {
    console.error('   For Docker: Add MONGODB_URI to docker-compose.yml or backend-api/.env file');
    console.error('   (docker-compose loads .env file from host at runtime)');
  } else {
    console.error('   For local: Add MONGODB_URI=your_connection_string to backend-api/.env');
  }
  console.error('');
  process.exit(1);
}

console.log('✓ Environment variables loaded');
console.log('✓ Service: MAIN API (backend-api)');
console.log('✓ Database: MongoDB');
console.log('✓ Port: ' + (process.env.PORT || 3000));

// Now import other modules
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { connectDatabase } from './config/database.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import { healthLimiter } from './middleware/rateLimiter.js';

// Import routes
import authRoutes from './routes/auth.routes.js';
import examRoutes from './routes/exam.routes.js';
import studentRoutes from './routes/student.routes.js';
import teacherRoutes from './routes/teacher.routes.js';
import questionRoutes from './routes/question.routes.js';
import examResultRoutes from './routes/examResult.routes.js';
import classRoutes from './routes/class.routes.js';
// Chat routes removed - handled by separate chat service (backend-chat)

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());

// CORS configuration
// Parse and trim ALLOWED_ORIGINS from environment variable
// Always include localhost for faster local development
const defaultOrigins = [
  'http://localhost:8080',
  'http://localhost:3000',
  'http://localhost:3001',
  'http://127.0.0.1:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3001',
];
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? [...defaultOrigins, ...process.env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim())]
  : defaultOrigins;

// Log allowed origins in development
if (process.env.NODE_ENV !== 'production') {
  console.log('📋 CORS Allowed Origins:', allowedOrigins);
}

app.use(cors({
  origin: (origin, callback) => {
    // Always allow localhost for faster local development
    if (!origin || origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
      return callback(null, true);
    }
    
    // Check if origin is in allowed list
    if (allowedOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    }
    
    // In development, allow all origins
    if (process.env.NODE_ENV === 'development') {
      return callback(null, true);
    }
    
    // Reject origin
    console.warn(`🚫 CORS blocked origin: ${origin}`);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
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

// Health check endpoint - lenient rate limiting
app.get('/health', healthLimiter, async (req, res) => {
  try {
    const db = await connectDatabase();
    await db.admin().ping();
    res.json({ 
      ok: true,
      service: 'MAIN API SERVICE',
      database: 'MongoDB',
      port: PORT,
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      endpoints: {
        auth: '/api/auth',
        exams: '/api/exams',
        students: '/api/students',
        teachers: '/api/teachers',
        questions: '/api/questions',
        examResults: '/api/exam-results',
        classes: '/api/classes'
      }
    });
  } catch (e) {
    res.status(500).json({ 
      ok: false,
      service: 'MAIN API SERVICE',
      database: 'MongoDB',
      error: String(e),
      timestamp: new Date().toISOString(),
      troubleshooting: [
        'Check MongoDB connection string in .env',
        'Verify MongoDB is accessible',
        'Check network/firewall settings'
      ]
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
app.use('/api/classes', classRoutes);
// Chat API removed - use separate chat service (backend-chat)

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
        classes: '/api/classes',
        note: 'Chat API is handled by separate service (backend-chat)'
      }
  });
});

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
    serverInstance = app.listen(PORT, () => {
      console.log('\n╔══════════════════════════════════════════════════════════╗');
      console.log('║     MAIN API SERVICE - Running                           ║');
      console.log('╚══════════════════════════════════════════════════════════╝');
      console.log(`\n✓ Service: MAIN API (backend-api)`);
      console.log(`✓ URL: http://localhost:${PORT}`);
      console.log(`✓ API: http://localhost:${PORT}/api`);
      console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✓ Database: MongoDB`);
      console.log('\n📋 Available endpoints:');
      console.log(`   - Health: http://localhost:${PORT}/health`);
      console.log(`   - Auth: http://localhost:${PORT}/api/auth`);
      console.log(`   - Exams: http://localhost:${PORT}/api/exams`);
      console.log(`   - Students: http://localhost:${PORT}/api/students`);
      console.log(`   - Teachers: http://localhost:${PORT}/api/teachers`);
      console.log(`   - Questions: http://localhost:${PORT}/api/questions`);
      console.log(`   - Exam Results: http://localhost:${PORT}/api/exam-results`);
      console.log(`   - Classes: http://localhost:${PORT}/api/classes`);
      console.log('\n💡 Note: Chat API is handled by separate service (backend-chat)\n');
    });
  } catch (error) {
    console.error('\n╔══════════════════════════════════════════════════════════╗');
    console.error('║     MAIN API SERVICE - Startup Failed                    ║');
    console.error('╚══════════════════════════════════════════════════════════╝');
    console.error('\n✗ Service: MAIN API (backend-api)');
    console.error('✗ Error:', error.message);
    console.error('\n📝 Troubleshooting:');
    console.error('   1. Check MongoDB connection string in .env');
    console.error('   2. Verify MongoDB is accessible');
    console.error('   3. Check network/firewall settings');
    console.error('   4. Review error details above\n');
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

// Shutdown endpoint for development
app.post('/shutdown', (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ ok: false, error: 'Shutdown disabled in production' });
  }
  const token = req.headers['x-shutdown-token'];
  if (!process.env.SHUTDOWN_TOKEN || token !== process.env.SHUTDOWN_TOKEN) {
    return res.status(401).json({ ok: false, error: 'Unauthorized' });
  }
  res.json({ ok: true, message: 'Shutting down server' });
  try {
    serverInstance?.close(() => {
      console.log('HTTP server closed');
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 5000).unref();
  } catch (e) {
    process.exit(0);
  }
});

