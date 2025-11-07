// Supabase database configuration for chat service
import { supabase } from './supabase.js';

let isConnected = false;

export async function connectDatabase() {
  if (isConnected) {
    return supabase;
  }

  try {
    // Test connection by querying a simple table
    const { error } = await supabase.from('chat_messages').select('id').limit(1);
    
    if (error && error.code !== 'PGRST116') { // PGRST116 = table doesn't exist
      console.error('\n╔══════════════════════════════════════════════════════════╗');
      console.error('║  ✗ CHAT SERVICE - Database Connection Failed          ║');
      console.error('╚══════════════════════════════════════════════════════════╝');
      console.error('✗ Service: CHAT SERVICE (backend-chat)');
      console.error('✗ Database: Supabase');
      console.error('✗ Error:', error.message);
      console.error('\n📝 Troubleshooting:');
      console.error('   1. Check SUPABASE_URL in backend-chat/.env');
      console.error('   2. Check SUPABASE_SERVICE_ROLE_KEY in backend-chat/.env');
      console.error('   3. Verify Supabase project is active');
      console.error('   4. Verify database tables exist in Supabase\n');
      throw error;
    }
    
    isConnected = true;
    console.log('✓ Connected to Supabase');
    return supabase;
  } catch (error) {
    if (!error.message || !error.message.includes('CHAT SERVICE')) {
      console.error('\n╔══════════════════════════════════════════════════════════╗');
      console.error('║  ✗ CHAT SERVICE - Database Connection Failed          ║');
      console.error('╚══════════════════════════════════════════════════════════╝');
      console.error('✗ Service: CHAT SERVICE (backend-chat)');
      console.error('✗ Database: Supabase');
      console.error('✗ Error:', error.message || error);
      console.error('\n📝 Troubleshooting:');
      console.error('   1. Check SUPABASE_URL in backend-chat/.env');
      console.error('   2. Check SUPABASE_SERVICE_ROLE_KEY in backend-chat/.env');
      console.error('   3. Verify Supabase project is active\n');
    }
    throw error;
  }
}

export async function closeDatabase() {
  // Supabase client doesn't need explicit closing
  isConnected = false;
  console.log('✓ Supabase connection closed');
}

export function getDatabase() {
  if (!isConnected) {
    throw new Error('Database not connected. Call connectDatabase() first.');
  }
  return supabase;
}

export { supabase as getSupabaseClient };

