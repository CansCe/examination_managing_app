// Cleanup script to delete chat messages older than 30 days
// Run this script periodically (e.g., via cron job or scheduled task)

import 'dotenv/config';
import { connectDatabase, getDatabase, closeDatabase } from '../config/database.js';

const DAYS_TO_KEEP = 30;

async function cleanupOldMessages() {
  let db;
  
  try {
    console.log('Starting cleanup of old chat messages...');
    console.log(`Deleting messages older than ${DAYS_TO_KEEP} days`);
    
    // Connect to database
    await connectDatabase();
    db = getDatabase();
    
    if (!db) {
      throw new Error('Database connection failed');
    }
    
    // Calculate the cutoff date (30 days ago)
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - DAYS_TO_KEEP);
    
    console.log(`Cutoff date: ${cutoffDate.toISOString()}`);
    
    // Delete messages older than 30 days
    const result = await db.collection('chat_messages').deleteMany({
      timestamp: { $lt: cutoffDate }
    });
    
    const deletedCount = result.deletedCount;
    
    console.log(`\nCleanup completed successfully!`);
    console.log(`Deleted ${deletedCount} message(s) older than ${DAYS_TO_KEEP} days`);
    
    // Get remaining message count
    const remainingCount = await db.collection('chat_messages').countDocuments();
    console.log(`Remaining messages in database: ${remainingCount}`);
    
    return {
      success: true,
      deletedCount,
      remainingCount,
      cutoffDate: cutoffDate.toISOString()
    };
    
  } catch (error) {
    console.error('Error during cleanup:', error);
    throw error;
  } finally {
    // Close database connection
    if (db) {
      await closeDatabase();
    }
  }
}

// Run cleanup if script is executed directly
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.includes('cleanup-old-messages.js')) {
  cleanupOldMessages()
    .then((result) => {
      console.log('\nCleanup result:', result);
      process.exit(0);
    })
    .catch((error) => {
      console.error('\nCleanup failed:', error);
      process.exit(1);
    });
}

export { cleanupOldMessages };

