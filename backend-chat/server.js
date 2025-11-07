// Load environment variables FIRST using dotenv/config
import 'dotenv/config';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================
// CHAT SERVICE (Supabase Backend)
// ============================================
console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║     CHAT SERVICE - Starting...                          ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');

// Verify .env file exists
const envPath = join(__dirname, '.env');
if (!existsSync(envPath)) {
  console.error('╔══════════════════════════════════════════════════════════╗');
  console.error('║  ✗ CHAT SERVICE - Configuration Error                  ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error(`\n✗ .env file not found at: ${envPath}`);
  console.error('✗ Service: CHAT SERVICE (backend-chat)');
  console.error('✗ Database: Supabase');
  console.error('\n📝 Solution:');
  console.error('   1. Copy ENV_EXAMPLE.txt to .env');
  console.error('   2. Fill in your SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  console.error('   3. Restart the service\n');
  process.exit(1);
}

// Verify Supabase credentials are loaded
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error('╔══════════════════════════════════════════════════════════╗');
  console.error('║  ✗ CHAT SERVICE - Configuration Error                  ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error('\n✗ Supabase credentials not found in environment variables');
  console.error('✗ Service: CHAT SERVICE (backend-chat)');
  console.error('✗ Database: Supabase');
  console.error('\n📝 Solution:');
  console.error('   Add SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY to backend-chat/.env');
  console.error('   Get credentials from: Supabase Dashboard > Settings > API\n');
  process.exit(1);
}

console.log('✓ Environment variables loaded');
console.log('✓ Service: CHAT SERVICE (backend-chat)');
console.log('✓ Database: Supabase');
console.log('✓ Port: ' + (process.env.PORT || 3001));

// Now import other modules
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { connectDatabase, closeDatabase } from './config/database.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import chatRoutes from './routes/chat.routes.js';

const app = express();
const PORT = process.env.PORT || 3001; // Different port from main API

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

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const supabase = await connectDatabase();
    const { error } = await supabase.from('chat_messages').select('id').limit(1);
    if (error && error.code !== 'PGRST116') {
      throw error;
    }
    res.json({ 
      ok: true,
      service: 'CHAT SERVICE',
      database: 'Supabase',
      port: PORT,
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      api: 'REST API (Realtime disabled)',
      endpoints: {
        chat: '/api/chat',
        conversations: '/api/chat/conversations',
        unread: '/api/chat/unread',
        defaultAdmin: '/api/chat/default-admin'
      }
    });
  } catch (e) {
    res.status(500).json({ 
      ok: false,
      service: 'CHAT SERVICE',
      database: 'Supabase',
      error: String(e),
      timestamp: new Date().toISOString(),
      troubleshooting: [
        'Check SUPABASE_URL in .env',
        'Check SUPABASE_SERVICE_ROLE_KEY in .env',
        'Verify Supabase project is active',
        'Verify database tables exist in Supabase'
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
    version: '1.0.0',
    endpoints: {
      health: '/health',
      chat: '/api/chat',
      api: 'REST API (Realtime replication disabled)'
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
    console.log('\n📡 Connecting to Supabase...');
    await connectDatabase();
    console.log('✓ Supabase connected');
    
    // Start listening
    serverInstance = app.listen(PORT, () => {
      console.log('\n╔══════════════════════════════════════════════════════════╗');
      console.log('║     CHAT SERVICE - Running                             ║');
      console.log('╚══════════════════════════════════════════════════════════╝');
      console.log(`\n✓ Service: CHAT SERVICE (backend-chat)`);
      console.log(`✓ URL: http://localhost:${PORT}`);
      console.log(`✓ API: http://localhost:${PORT}/api/chat`);
      console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✓ Database: Supabase`);
      console.log(`✓ API: REST API (Realtime replication disabled)`);
      console.log('\n📋 Available endpoints:');
      console.log(`   - Health: http://localhost:${PORT}/health`);
      console.log(`   - Chat: http://localhost:${PORT}/api/chat`);
      console.log(`   - Conversations: http://localhost:${PORT}/api/chat/conversations`);
      console.log(`   - Unread: http://localhost:${PORT}/api/chat/unread`);
      console.log(`   - Default Admin: http://localhost:${PORT}/api/chat/default-admin`);
      console.log('\n💡 Note: This service handles all chat functionality\n');
    });
  } catch (error) {
    console.error('\n╔══════════════════════════════════════════════════════════╗');
    console.error('║  ✗ CHAT SERVICE - Startup Failed                      ║');
    console.error('╚══════════════════════════════════════════════════════════╝');
    console.error('\n✗ Service: CHAT SERVICE (backend-chat)');
    console.error('✗ Error:', error.message);
    console.error('\n📝 Troubleshooting:');
    console.error('   1. Check SUPABASE_URL in .env');
    console.error('   2. Check SUPABASE_SERVICE_ROLE_KEY in .env');
    console.error('   3. Verify Supabase project is active');
    console.error('   4. Verify database tables exist in Supabase');
    console.error('   5. Review error details above\n');
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  await closeDatabase();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT signal received: closing HTTP server');
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
      await closeDatabase();
      console.log('Chat service closed');
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 5000).unref();
  } catch (e) {
    process.exit(0);
  }
});

