// MongoDB database configuration
import { MongoClient } from 'mongodb';

// Get MongoDB URI - check lazily to ensure env vars are loaded
function getMongoUri() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('Missing MONGODB_URI in environment. Make sure .env file is loaded.');
  }
  return mongoUri;
}

const dbName = process.env.MONGODB_DB || 'exam_management';

let client = null;
let db = null;

export async function connectDatabase() {
  if (db) {
    return db;
  }

  try {
    const mongoUri = getMongoUri();
    if (!client || !client.topology || !client.topology.isConnected()) {
      client = new MongoClient(mongoUri, {
        serverSelectionTimeoutMS: 5000,
        retryWrites: true,
      });
      await client.connect();
      console.log('✓ Connected to MongoDB');
    }
    
    db = client.db(dbName);
    return db;
  } catch (error) {
    console.error('\n╔══════════════════════════════════════════════════════════╗');
    console.error('║  ✗ MAIN API SERVICE - Database Connection Failed      ║');
    console.error('╚══════════════════════════════════════════════════════════╝');
    console.error('✗ Service: MAIN API (backend-api)');
    console.error('✗ Database: MongoDB');
    console.error('✗ Error:', error.message);
    console.error('\n📝 Troubleshooting:');
    console.error('   1. Check MONGODB_URI in backend-api/.env');
    console.error('   2. Verify MongoDB is accessible');
    console.error('   3. Check network/firewall settings');
    console.error('   4. Ensure MongoDB server is running\n');
    throw error;
  }
}

export async function closeDatabase() {
  if (client) {
    await client.close();
    client = null;
    db = null;
    console.log('✓ MongoDB connection closed');
  }
}

export function getDatabase() {
  if (!db) {
    throw new Error('Database not connected. Call connectDatabase() first.');
  }
  return db;
}
