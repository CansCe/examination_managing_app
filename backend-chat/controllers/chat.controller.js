import { getDatabase, ObjectId } from '../config/database.js';
import { validationResult } from 'express-validator';
import { isValidUuid, isValidObjectId, toObjectId } from '../utils/supabase-helpers.js';
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

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: decodeUserId(fromUserId),
      from_user_role: 'student',
      to_user_id: decodeUserId(toUserId),
      to_user_role: toUserRole || 'admin',
      message: message,
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // Broadcast message via Socket.io
    const io = getIO();
    if (io) {
      io.to(conversationId).emit('message_received', {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      });
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

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: decodeUserId(fromUserId),
      from_user_role: 'teacher',
      to_user_id: decodeUserId(toUserId),
      to_user_role: toUserRole || 'student',
      message: message,
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // Broadcast message via Socket.io
    const io = getIO();
    if (io) {
      io.to(conversationId).emit('message_received', {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      });
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

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: decodeUserId(fromUserId),
      from_user_role: 'admin',
      to_user_id: decodeUserId(toUserId),
      to_user_role: toUserRole || 'student',
      message: message,
      is_read: false,
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('chat_messages').insertOne(chatMessage);
    const insertedMessage = await db.collection('chat_messages').findOne({ _id: result.insertedId });

    // When an admin replies, mark all unread student messages as read for this student
    const updateResult = await db.collection('chat_messages').updateMany(
      {
        from_user_id: decodeUserId(toUserId),
        from_user_role: 'student',
        is_read: false
      },
      {
        $set: {
          is_read: true,
          answered_by: decodeUserId(fromUserId),
          answered_at: new Date(),
          updatedAt: new Date()
        }
      }
    );

    // Broadcast message via Socket.io
    const io = getIO();
    if (io) {
      io.to(conversationId).emit('message_received', {
        ...insertedMessage,
        id: insertedMessage._id.toString()
      });
      // Notify about read status update
      if (updateResult.modifiedCount > 0) {
        io.to(conversationId).emit('messages_read', {
          conversationId,
          count: updateResult.modifiedCount
        });
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

    // Only return messages from the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Create conversation ID (sorted)
    const conversationId = createConversationId(userId, targetUserId);
    
    // Try to find messages with this conversation ID
    // Also try with decoded IDs if they're UUIDs
    let messages = await db.collection('chat_messages')
      .find({
        conversation_id: conversationId,
        timestamp: { $gte: thirtyDaysAgo }
      })
      .sort({ timestamp: 1 })
      .toArray();

    // If no messages found and IDs are UUIDs, try with decoded ObjectIds
    if (messages.length === 0 && isValidUuid(userId) && isValidUuid(targetUserId)) {
      // Try to decode UUIDs back to ObjectIds (if they were encoded)
      // For now, just return empty - messages will be created with the UUID format
      // This handles the case where old messages used ObjectIds and new ones use UUIDs
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
        conversationsMap.set(convId, {
          conversationId: convId,
          lastMessage: msg,
          studentId: msg.from_user_role === 'student' ? msg.from_user_id : 
                    (msg.to_user_role === 'student' ? msg.to_user_id : null)
        });
      }
    });

    // Count unread messages per conversation
    const conversations = await Promise.all(
      Array.from(conversationsMap.values()).map(async (conv) => {
        if (!conv.studentId) return null;

        const unreadCount = await db.collection('chat_messages').countDocuments({
          conversation_id: conv.conversationId,
          from_user_role: 'student',
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

    const unread = await db.collection('chat_messages')
      .find({
        from_user_role: 'student',
        is_read: false,
        timestamp: { $gte: thirtyDaysAgo }
      })
      .sort({ timestamp: -1 })
      .toArray();

    res.json({ success: true, data: unread || [] });
  } catch (error) {
    console.error('Get unread messages error:', error);
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
    const { studentId } = req.params;
    const db = getDatabase();

    if (!studentId) {
      return res.status(400).json({ success: false, error: 'Missing studentId' });
    }

    const result = await db.collection('chat_messages').updateMany(
      {
        from_user_id: decodeUserId(studentId),
        from_user_role: 'student',
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
