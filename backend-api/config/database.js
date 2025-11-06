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

    // Ensure indexes for chat efficiency and TTL cleanup
    try {
      await db.collection('chat_messages').createIndexes([
        { key: { conversationId: 1, timestamp: 1 }, name: 'conv_ts_asc' },
        { key: { fromUserId: 1, fromUserRole: 1, isRead: 1, timestamp: -1 }, name: 'from_unread_ts_desc' },
        { key: { toUserId: 1, toUserRole: 1, isRead: 1, timestamp: -1 }, name: 'to_unread_ts_desc' },
      ]);
      // TTL index (30 days) on timestamp; note TTL cannot be compound and requires a Date value
      // If index exists, this is a no-op
      await db.collection('chat_messages').createIndex(
        { timestamp: 1 },
        { name: 'ttl_30d', expireAfterSeconds: 60 * 60 * 24 * 30 }
      );
    } catch (e) {
      console.warn('Warning: failed to create chat indexes', e);
    }
    return db;
  } catch (error) {
    console.error('✗ MongoDB connection error:', error);
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

