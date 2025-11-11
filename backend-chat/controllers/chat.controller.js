import { getDatabase, ObjectId } from '../config/database.js';
import { validationResult } from 'express-validator';
import { isValidUuid, isValidObjectId, toObjectId, sanitizeUserId, sanitizeUserRole } from '../utils/supabase-helpers.js';
import { getIO } from '../config/socket.js';

// Helper to decode UUID back to MongoDB ObjectId if needed
function decodeUserId(userId) {
  // If it's already a MongoDB ObjectId (24 hex chars), return it
  if (isValidObjectId(userId)) {
    return userId;
  }
  // If it's a UUID, try to decode it (for backward compatibility with encoded IDs)
  // The Flutter app encodes MongoDB ObjectIds to UUIDs for chat service
  // We'll store both formats and match on either
  return userId;
}

// Helper to create conversation ID that works with both formats
function createConversationId(userId1, userId2) {
  // Normalize both IDs (decode if needed, but keep original for matching)
  const ids = [userId1, userId2].sort();
  return ids.join(':');
}

export const sendStudentMessage = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { fromUserId, toUserId, toUserRole, message } = req.body;
    const db = getDatabase();

    if (!fromUserId || !toUserId || !message) {
      return res.status(400).json({ success: false, error: 'Missing required fields' });
    }

    // Use the IDs as-is for conversation_id to match query format
    const conversationId = createConversationId(fromUserId, toUserId);
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: fromUserId, // Store as-is (can be UUID or ObjectId)
      from_user_role: 'student',
      to_user_id: toUserId, // Store as-is (can be UUID or ObjectId)
      to_user_role: toUserRole || 'admin',
      message: message,
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // Broadcast message via Socket.io to all clients in the conversation room
    const io = getIO();
    if (io) {
      const messagePayload = {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      };
      
      // Broadcast to the conversation room (both sender and receiver should be in this room)
      io.to(conversationId).emit('message_received', messagePayload);
      
      // Also try reverse conversation ID in case clients joined with different order
      const reverseConversationId = createConversationId(toUserId, fromUserId);
      if (reverseConversationId !== conversationId) {
        io.to(reverseConversationId).emit('message_received', messagePayload);
      }
      
      console.log(`Broadcasted student message to conversation room: ${conversationId} (and ${reverseConversationId})`);
      console.log(`   Message: ${message.substring(0, 50)}${message.length > 50 ? '...' : ''}`);
    }

    res.status(201).json({ success: true, data: insertedMessage });
  } catch (error) {
    console.error('Send student message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const sendTeacherMessage = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { fromUserId, toUserId, toUserRole, message } = req.body;
    const db = getDatabase();

    if (!fromUserId || !toUserId || !message) {
      return res.status(400).json({ success: false, error: 'Missing required fields' });
    }

    // SECURITY: Sanitize user IDs before using in database operations
    const sanitizedFromUserId = sanitizeUserId(fromUserId);
    const sanitizedToUserId = sanitizeUserId(toUserId);
    const sanitizedToUserRole = toUserRole ? sanitizeUserRole(toUserRole) : 'admin';

    if (!sanitizedFromUserId) {
      return res.status(400).json({ success: false, error: 'Invalid fromUserId format' });
    }

    if (!sanitizedToUserId) {
      return res.status(400).json({ success: false, error: 'Invalid toUserId format' });
    }

    // Use sanitized IDs for conversation_id
    const conversationId = createConversationId(sanitizedFromUserId, sanitizedToUserId);
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: sanitizedFromUserId, // Sanitized user ID
      from_user_role: 'teacher',
      to_user_id: sanitizedToUserId, // Sanitized user ID
      to_user_role: sanitizedToUserRole || 'admin', // Default to 'admin' for teacher messages (teachers usually message admins)
      message: message.trim().substring(0, 5000), // Limit message length and trim
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    console.log(`Teacher message: from ${sanitizedFromUserId} to ${sanitizedToUserId} (role: ${sanitizedToUserRole || 'admin'})`);

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // Broadcast message via Socket.io to all clients in the conversation room
    const io = getIO();
    if (io) {
      const messagePayload = {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      };
      
      // Broadcast to the conversation room (both sender and receiver should be in this room)
      io.to(conversationId).emit('message_received', messagePayload);
      
      // Also try reverse conversation ID in case clients joined with different order
      const reverseConversationId = createConversationId(sanitizedToUserId, sanitizedFromUserId);
      if (reverseConversationId !== conversationId) {
        io.to(reverseConversationId).emit('message_received', messagePayload);
      }
      
      console.log(`Broadcasted teacher message to conversation room: ${conversationId} (and ${reverseConversationId})`);
      console.log(`   Message: ${message.substring(0, 50)}${message.length > 50 ? '...' : ''}`);
    }

    res.status(201).json({ success: true, data: insertedMessage });
  } catch (error) {
    console.error('Send teacher message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const sendAdminMessage = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { fromUserId, toUserId, toUserRole, message } = req.body;
    const db = getDatabase();

    if (!fromUserId || !toUserId || !message) {
      return res.status(400).json({ success: false, error: 'Missing required fields' });
    }

    // SECURITY: Sanitize user IDs before using in database operations
    const sanitizedFromUserId = sanitizeUserId(fromUserId);
    const sanitizedToUserId = sanitizeUserId(toUserId);
    const sanitizedToUserRole = toUserRole ? sanitizeUserRole(toUserRole) : 'student';

    if (!sanitizedFromUserId) {
      return res.status(400).json({ success: false, error: 'Invalid fromUserId format' });
    }

    if (!sanitizedToUserId) {
      return res.status(400).json({ success: false, error: 'Invalid toUserId format' });
    }

    // Use sanitized IDs for conversation_id
    const conversationId = createConversationId(sanitizedFromUserId, sanitizedToUserId);
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: sanitizedFromUserId, // Sanitized user ID
      from_user_role: 'admin',
      to_user_id: sanitizedToUserId, // Sanitized user ID
      to_user_role: sanitizedToUserRole || 'student',
      message: message.trim().substring(0, 5000), // Limit message length and trim
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // When an admin replies, mark all unread messages as read (from both students and teachers)
    // Note: sanitizedToUserId and sanitizedFromUserId are already validated above
    let updateResult = { modifiedCount: 0 };
    if (sanitizedToUserId && sanitizedFromUserId) {
      try {
        updateResult = await db.collection('chat_messages').updateMany(
          {
            from_user_id: sanitizedToUserId, // Sanitized user ID
            $or: [
              { from_user_role: 'student' },
              { from_user_role: 'teacher' }
            ],
            to_user_role: 'admin',
            is_read: false
          },
          {
            $set: {
              is_read: true,
              answered_by: sanitizedFromUserId, // Sanitized user ID
              answered_at: new Date(),
              updatedAt: new Date()
            }
          }
        );
        
        console.log(`Admin replied: Marked ${updateResult.modifiedCount} messages as read from ${sanitizedToUserRole || 'user'}`);
      } catch (updateError) {
        console.error('Error marking messages as read:', updateError);
        // Continue even if marking as read fails (message was already sent)
      }
    }
    
    // Broadcast message via Socket.io to all clients in the conversation room
    const io = getIO();
    if (io) {
      const messagePayload = {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      };
      
      // Broadcast to the conversation room (both sender and receiver should be in this room)
      io.to(conversationId).emit('message_received', messagePayload);
      
      // Also try reverse conversation ID in case clients joined with different order
      const reverseConversationId = createConversationId(sanitizedToUserId, sanitizedFromUserId);
      if (reverseConversationId !== conversationId) {
        io.to(reverseConversationId).emit('message_received', messagePayload);
      }
      
      console.log(`Broadcasted admin message to conversation room: ${conversationId} (and ${reverseConversationId})`);
      console.log(`   Message: ${message.substring(0, 50)}${message.length > 50 ? '...' : ''}`);
      
      // Notify about read status update (only if we successfully updated)
      if (updateResult.modifiedCount > 0) {
        io.to(conversationId).emit('messages_read', {
          conversationId,
          count: updateResult.modifiedCount
        });
        if (reverseConversationId !== conversationId) {
          io.to(reverseConversationId).emit('messages_read', {
            conversationId: reverseConversationId,
            count: updateResult.modifiedCount
          });
        }
      }
    }

    res.status(201).json({ success: true, data: insertedMessage });
  } catch (error) {
    console.error('Send admin message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversation = async (req, res) => {
  try {
    const { userId, targetUserId } = req.query;
    const db = getDatabase();

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, error: 'Missing userId or targetUserId' });
    }

    // SECURITY: Sanitize user inputs before using in database queries
    const sanitizedUserId = sanitizeUserId(userId);
    const sanitizedTargetUserId = sanitizeUserId(targetUserId);

    if (!sanitizedUserId) {
      return res.status(400).json({ success: false, error: 'Invalid userId format' });
    }

    if (!sanitizedTargetUserId) {
      return res.status(400).json({ success: false, error: 'Invalid targetUserId format' });
    }

    // Only return messages from the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Create conversation ID (sorted) - use sanitized IDs
    const conversationId = createConversationId(sanitizedUserId, sanitizedTargetUserId);
    
    console.log(`  Querying conversation with ID: ${conversationId}`);
    console.log(`  userId format: ${isValidUuid(sanitizedUserId) ? 'UUID' : isValidObjectId(sanitizedUserId) ? 'ObjectId' : 'Unknown'}`);
    console.log(`  targetUserId format: ${isValidUuid(sanitizedTargetUserId) ? 'UUID' : isValidObjectId(sanitizedTargetUserId) ? 'ObjectId' : 'Unknown'}`);
    
    // Try to find messages with this conversation ID
    let messages = await db.collection('chat_messages')
      .find({
        conversation_id: conversationId,
        timestamp: { $gte: thirtyDaysAgo }
      })
      .sort({ timestamp: 1 })
      .toArray();

    console.log(`  Found ${messages.length} messages with conversation ID: ${conversationId}`);
    if (messages.length > 0) {
      console.log(`  Message roles in conversation: ${messages.map(m => `${m.from_user_role}->${m.to_user_role}`).join(', ')}`);
    }

    // If no messages found, try alternative conversation ID (reverse order)
    // This handles cases where messages were stored with different ID order
    if (messages.length === 0) {
      const reverseConversationId = createConversationId(sanitizedTargetUserId, sanitizedUserId);
      if (reverseConversationId !== conversationId) {
        console.log(`  Trying reverse conversation ID: ${reverseConversationId}`);
        const reverseMessages = await db.collection('chat_messages')
          .find({
            conversation_id: reverseConversationId,
            timestamp: { $gte: thirtyDaysAgo }
          })
          .sort({ timestamp: 1 })
          .toArray();
        
        if (reverseMessages.length > 0) {
          console.log(`  Found ${reverseMessages.length} messages with reverse conversation ID`);
          messages = reverseMessages;
        }
      }
    }

    // If no messages found and IDs are UUIDs, try with ObjectId format (decoded)
    if (messages.length === 0 && isValidUuid(sanitizedUserId) && isValidUuid(sanitizedTargetUserId)) {
      // Try to decode UUIDs back to ObjectIds
      // UUID format: 454d4150-XXXX-XXXX-XXXX-XXXXXXXXXXXX
      // Extract ObjectId from UUID parts
      try {
        const decodeFromUuid = (uuid) => {
          if (!isValidUuid(uuid)) return uuid;
          const parts = uuid.split('-');
          if (parts.length === 5 && parts[0].toLowerCase() === '454d4150') {
            // Extract ObjectId from remaining parts
            const hexString = parts.slice(1).join('');
            if (hexString.length >= 24) {
              const decoded = hexString.substring(0, 24);
              // SECURITY: Sanitize decoded ID before using
              return sanitizeUserId(decoded) || uuid;
            }
          }
          return uuid;
        };
        
        const decodedUserId = decodeFromUuid(sanitizedUserId);
        const decodedTargetUserId = decodeFromUuid(sanitizedTargetUserId);
        // SECURITY: Sanitize decoded IDs
        const sanitizedDecodedUserId = sanitizeUserId(decodedUserId);
        const sanitizedDecodedTargetUserId = sanitizeUserId(decodedTargetUserId);
        
        if (!sanitizedDecodedUserId || !sanitizedDecodedTargetUserId) {
          throw new Error('Invalid decoded user IDs');
        }
        
        const decodedConversationId = createConversationId(sanitizedDecodedUserId, sanitizedDecodedTargetUserId);
        
        console.log(`  Trying decoded conversation ID: ${decodedConversationId}`);
        
        messages = await db.collection('chat_messages')
          .find({
            conversation_id: decodedConversationId,
            timestamp: { $gte: thirtyDaysAgo }
          })
          .sort({ timestamp: 1 })
          .toArray();
        
        console.log(`  Found ${messages.length} messages with decoded conversation ID`);
        if (messages.length > 0) {
          console.log(`  Message roles: ${messages.map(m => `${m.from_user_role}->${m.to_user_role}`).join(', ')}`);
        }
      } catch (e) {
        console.error('  Error decoding UUIDs:', e);
      }
    }
    
    // Fallback: Query by user IDs directly if conversation ID didn't work
    // This handles cases where ID encoding causes conversation ID mismatches
    if (messages.length === 0) {
      console.log(`  ⚠ No messages found with conversation ID, trying direct user ID query as fallback...`);
      
      // Query for messages between these two specific users
      // SECURITY: Use sanitized IDs
      const directMessages = await db.collection('chat_messages')
        .find({
          $or: [
            // Direct matches with sanitized IDs
            { from_user_id: sanitizedUserId, to_user_id: sanitizedTargetUserId },
            { from_user_id: sanitizedTargetUserId, to_user_id: sanitizedUserId },
          ],
          timestamp: { $gte: thirtyDaysAgo }
        })
        .sort({ timestamp: 1 })
        .toArray();
      
      console.log(`  Direct query found ${directMessages.length} messages`);
      
      if (directMessages.length > 0) {
        console.log(`  ✅ Found ${directMessages.length} messages with direct user ID query`);
        messages = directMessages;
      } else {
        console.log(`  ❌ No messages found with direct query`);
        console.log(`  Trying broader search with all messages involving these users...`);
        
        // Broader search: find all messages where either user is involved
        // SECURITY: Use sanitized IDs
        const allUserMessages = await db.collection('chat_messages')
          .find({
            $or: [
              { from_user_id: sanitizedUserId },
              { from_user_id: sanitizedTargetUserId },
              { to_user_id: sanitizedUserId },
              { to_user_id: sanitizedTargetUserId }
            ],
            timestamp: { $gte: thirtyDaysAgo }
          })
          .sort({ timestamp: 1 })
          .toArray();
        
        console.log(`  Found ${allUserMessages.length} total messages involving these users`);
        
        // Filter to only messages between the two specific users
        const filteredMessages = allUserMessages.filter(msg => {
          const fromId = msg.from_user_id?.toString() || '';
          const toId = msg.to_user_id?.toString() || '';
          const userIdStr = sanitizedUserId.toString();
          const targetUserIdStr = sanitizedTargetUserId.toString();
          
          // Message is between our two users if both from and to match our users
          const isBetweenUsers = (
            (fromId === userIdStr || fromId === targetUserIdStr) &&
            (toId === userIdStr || toId === targetUserIdStr) &&
            fromId !== toId
          );
          
          if (isBetweenUsers) {
            console.log(`    ✓ Message between users: ${fromId} -> ${toId} (${msg.from_user_role} -> ${msg.to_user_role})`);
          }
          
          return isBetweenUsers;
        });
        
        if (filteredMessages.length > 0) {
          console.log(`  ✅ Found ${filteredMessages.length} messages after filtering`);
          messages = filteredMessages;
        } else {
          console.log(`  ❌ No messages found even after filtering`);
        }
      }
    }

    console.log(`  📋 Final result: ${messages.length} messages found for conversation`);
    if (messages.length > 0) {
      console.log(`  Message roles: ${messages.map(m => `${m.from_user_role}->${m.to_user_role}`).join(', ')}`);
    }
    
    res.json({ success: true, data: messages || [] });
  } catch (error) {
    console.error('Get conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getAllConversations = async (req, res) => {
  try {
    const db = getDatabase();

    // Get distinct conversation IDs from last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const messages = await db.collection('chat_messages')
      .find({
        timestamp: { $gte: thirtyDaysAgo }
      })
      .sort({ timestamp: -1 })
      .toArray();

    // Group by conversation_id and get last message
    const conversationsMap = new Map();
    messages.forEach(msg => {
      const convId = msg.conversation_id;
      if (!conversationsMap.has(convId)) {
        // Determine if this is a student or teacher conversation
        const isStudentConv = msg.from_user_role === 'student' || msg.to_user_role === 'student';
        const isTeacherConv = msg.from_user_role === 'teacher' || msg.to_user_role === 'teacher';
        
        conversationsMap.set(convId, {
          conversationId: convId,
          lastMessage: msg,
          studentId: isStudentConv ? (msg.from_user_role === 'student' ? msg.from_user_id : msg.to_user_id) : null,
          teacherId: isTeacherConv ? (msg.from_user_role === 'teacher' ? msg.from_user_id : msg.to_user_id) : null,
          userRole: isStudentConv ? 'student' : (isTeacherConv ? 'teacher' : null),
          userId: isStudentConv ? (msg.from_user_role === 'student' ? msg.from_user_id : msg.to_user_id) :
                  (isTeacherConv ? (msg.from_user_role === 'teacher' ? msg.from_user_id : msg.to_user_id) : null)
        });
      }
    });

    // Count unread messages per conversation
    const conversations = await Promise.all(
      Array.from(conversationsMap.values()).map(async (conv) => {
        // Skip if neither studentId nor teacherId (shouldn't happen, but safety check)
        if (!conv.userId) return null;

        // Count unread messages from the user (student or teacher) to admin
        const unreadCount = await db.collection('chat_messages').countDocuments({
          conversation_id: conv.conversationId,
          from_user_role: conv.userRole, // 'student' or 'teacher'
          to_user_role: 'admin',
          is_read: false
        });

        return {
          ...conv,
          unreadCount: unreadCount || 0
        };
      })
    );

    res.json({ success: true, data: conversations.filter(Boolean) });
  } catch (error) {
    console.error('Get all conversations error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getUnreadMessages = async (req, res) => {
  try {
    const db = getDatabase();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Get unread messages from both students and teachers (sent to admin)
    const unread = await db.collection('chat_messages')
      .find({
        $or: [
          { from_user_role: 'student', is_read: false },
          { from_user_role: 'teacher', is_read: false }
        ],
        to_user_role: 'admin', // Only messages sent to admin
        timestamp: { $gte: thirtyDaysAgo }
      })
      .sort({ timestamp: -1 })
      .toArray();

    console.log(`📊 Found ${unread.length} unread messages (students: ${unread.filter(m => m.from_user_role === 'student').length}, teachers: ${unread.filter(m => m.from_user_role === 'teacher').length})`);

    res.json({ success: true, data: unread || [] });
  } catch (error) {
    console.error('Get unread messages error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Get unread message count for a specific user (student or teacher)
export const getUnreadCount = async (req, res) => {
  try {
    const { userId, userRole } = req.query;
    const db = getDatabase();

    if (!userId || !userRole) {
      return res.status(400).json({ success: false, error: 'Missing userId or userRole' });
    }

    // SECURITY: Sanitize user inputs before using in database query
    const sanitizedUserId = sanitizeUserId(userId);
    const sanitizedUserRole = sanitizeUserRole(userRole);

    if (!sanitizedUserId) {
      return res.status(400).json({ success: false, error: 'Invalid userId format' });
    }

    if (!sanitizedUserRole) {
      return res.status(400).json({ success: false, error: 'Invalid userRole. Must be student, teacher, or admin' });
    }

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Get unread messages sent TO this user (from admin)
    // SECURITY: Use sanitized values to prevent NoSQL injection
    const count = await db.collection('chat_messages').countDocuments({
      to_user_id: sanitizedUserId, // Sanitized user ID
      to_user_role: sanitizedUserRole, // Sanitized user role
      from_user_role: 'admin',
      is_read: false,
      timestamp: { $gte: thirtyDaysAgo }
    });

    console.log(`📊 Unread count for ${sanitizedUserRole} ${sanitizedUserId}: ${count}`);

    res.json({ success: true, count: count || 0 });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getDefaultAdmin = async (req, res) => {
  try {
    const db = getDatabase();
    
    // Fallback to configured default admin if provided
    const envAdmin = process.env.DEFAULT_ADMIN_ID;
    if (envAdmin) {
      return res.json({ success: true, adminId: envAdmin });
    }

    // Try to find the most recent active admin from chat history
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentAdminMessage = await db.collection('chat_messages')
      .findOne({
        from_user_role: 'admin',
        timestamp: { $gte: thirtyDaysAgo }
      }, {
        sort: { timestamp: -1 }
      });

    if (recentAdminMessage) {
      return res.json({ success: true, adminId: recentAdminMessage.from_user_id });
    }

    // Fallback: look for any admin who has ever received chat
    const anyAdmin = await db.collection('chat_messages')
      .findOne({
        to_user_role: 'admin'
      });

    if (anyAdmin) {
      return res.json({ success: true, adminId: anyAdmin.to_user_id });
    }

    // Fallback 3: pick any user with admin role from main users collection
    const adminUser = await db.collection('users')
      .findOne({
        role: 'admin'
      });

    if (adminUser) {
      return res.json({ success: true, adminId: adminUser._id.toString() });
    }

    return res.status(404).json({ success: false, error: 'No admin available' });
  } catch (error) {
    console.error('Get default admin error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const markAsRead = async (req, res) => {
  try {
    const { studentId } = req.params; // This can be studentId or teacherId
    const db = getDatabase();

    if (!studentId) {
      return res.status(400).json({ success: false, error: 'Missing studentId/teacherId' });
    }

    // SECURITY: Sanitize user ID before using in database query
    const sanitizedStudentId = sanitizeUserId(studentId);
    if (!sanitizedStudentId) {
      return res.status(400).json({ success: false, error: 'Invalid studentId/teacherId format' });
    }

    // Mark messages as read for both students and teachers (whoever sent messages to admin)
    // SECURITY: Use sanitized ID to prevent NoSQL injection
    const result = await db.collection('chat_messages').updateMany(
      {
        from_user_id: sanitizedStudentId, // Sanitized user ID
        $or: [
          { from_user_role: 'student' },
          { from_user_role: 'teacher' }
        ],
        to_user_role: 'admin', // Only messages sent to admin
        is_read: false
      },
      {
        $set: {
          is_read: true,
          read_at: new Date(),
          updatedAt: new Date()
        }
      }
    );

    // Broadcast read status update via Socket.io
    const io = getIO();
    if (io && result.modifiedCount > 0) {
      // Find conversations involving this user (student or teacher)
      // SECURITY: Use sanitized ID
      const conversations = await db.collection('chat_messages').distinct('conversation_id', {
        from_user_id: sanitizedStudentId, // Sanitized user ID
        $or: [
          { from_user_role: 'student' },
          { from_user_role: 'teacher' }
        ]
      });
      
      conversations.forEach(conversationId => {
        io.to(conversationId).emit('messages_read', {
          conversationId,
          count: result.modifiedCount,
          userId: sanitizedStudentId // Sanitized user ID
        });
      });
      
      console.log(`  📖 Broadcasted read status for ${result.modifiedCount} messages in ${conversations.length} conversation(s)`);
    }

    res.json({ success: true, message: 'Messages marked as read', count: result.modifiedCount });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const closeConversation = async (req, res) => {
  try {
    const { userId, targetUserId } = req.params;
    const body = req.body || {};
    const { topic, priority, assignedAdmin } = Object.keys(body).length > 0 ? body : req.query || {};
    const db = getDatabase();

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, error: 'Missing userId or targetUserId' });
    }

    const conversationId = [userId, targetUserId].sort().join(':');

    // Delete messages
    const deleteResult = await db.collection('chat_messages').deleteMany({
      conversation_id: conversationId
    });

    // Update conversation metadata
    const conversationData = {
      id: conversationId,
      participant_1: userId < targetUserId ? userId : targetUserId,
      participant_2: userId < targetUserId ? targetUserId : userId,
      status: 'closed',
      closed_at: new Date(),
      updated_at: new Date(),
      ...(topic && { topic }),
      ...(priority && { priority }),
      ...(assignedAdmin && { assigned_admin: assignedAdmin })
    };

    await db.collection('conversations').updateOne(
      { id: conversationId },
      { $set: conversationData },
      { upsert: true }
    );

    res.json({ success: true, deleted: deleteResult.deletedCount || 0 });
  } catch (error) {
    console.error('Close conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const createOrUpdateConversation = async (req, res) => {
  try {
    const { userId, targetUserId, topic, priority, assignedAdmin } = req.body;
    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, error: 'userId and targetUserId required' });
    }

    const db = getDatabase();
    const conversationId = [userId, targetUserId].sort().join(':');

    const conversationData = {
      id: conversationId,
      participant_1: userId < targetUserId ? userId : targetUserId,
      participant_2: userId < targetUserId ? targetUserId : userId,
      updated_at: new Date(),
      ...(topic && { topic }),
      ...(priority && { priority }),
      ...(assignedAdmin && { assigned_admin: assignedAdmin })
    };

    const conversation = await db.collection('conversations').findOneAndUpdate(
      { id: conversationId },
      { $set: conversationData },
      { upsert: true, returnDocument: 'after' }
    );

    res.json({ success: true, data: conversation.value || conversationData });
  } catch (error) {
    console.error('Create/update conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversationMetadata = async (req, res) => {
  try {
    const { userId, targetUserId } = req.params;
    const db = getDatabase();

    if (!userId || !targetUserId) {
      return res.status(400).json({ success: false, error: 'Missing userId or targetUserId' });
    }

    const conversationId = [userId, targetUserId].sort().join(':');
    const conversation = await db.collection('conversations').findOne({
      id: conversationId
    });

    res.json({ success: true, data: conversation || null });
  } catch (error) {
    console.error('Get conversation metadata error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};
