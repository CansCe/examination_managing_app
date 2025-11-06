import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

export const sendStudentMessage = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { fromUserId, toUserId, toUserRole, message } = req.body;
    const db = getDatabase();

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      _id: new ObjectId(),
      conversationId,
      fromUserId: new ObjectId(fromUserId),
      fromUserRole: 'student',
      toUserId: new ObjectId(toUserId),
      toUserRole: toUserRole || 'admin',
      message: message,
      timestamp: new Date().toISOString(),
      isRead: false,
      createdAt: new Date().toISOString()
    };

    await db.collection('chat_messages').insertOne(chatMessage);

    res.status(201).json({ success: true, data: chatMessage });
  } catch (error) {
    console.error('Send student message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const closeConversation = async (req, res) => {
  try {
    const { userId, targetUserId } = req.params;
    // For DELETE, body might be in req.body or query params
    const body = req.body || {};
    const { topic, priority, assignedAdmin } = Object.keys(body).length > 0 ? body : req.query || {};
    const db = getDatabase();
    const conversationId = [userId, targetUserId].sort().join(':');

    const deleteResult = await db.collection('chat_messages').deleteMany({ conversationId });
    // Record status in conversations collection with metadata
    await db.collection('conversations').updateOne(
      { _id: conversationId },
      {
        $set: {
          status: 'closed',
          closedAt: new Date().toISOString(),
          topic: topic || null,
          priority: priority || 'normal',
          assignedAdmin: assignedAdmin ? new ObjectId(assignedAdmin) : null
        },
        $setOnInsert: {
          participants: [userId, targetUserId],
          createdAt: new Date().toISOString()
        }
      },
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

    const conversation = await db.collection('conversations').findOneAndUpdate(
      { _id: conversationId },
      {
        $set: {
          participants: [userId, targetUserId],
          updatedAt: new Date().toISOString(),
          ...(topic && { topic }),
          ...(priority && { priority }),
          ...(assignedAdmin && { assignedAdmin: new ObjectId(assignedAdmin) })
        },
        $setOnInsert: {
          status: 'open',
          createdAt: new Date().toISOString()
        }
      },
      { upsert: true, returnDocument: 'after' }
    );

    res.json({ success: true, data: conversation.value || conversation });
  } catch (error) {
    console.error('Create/update conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversationMetadata = async (req, res) => {
  try {
    const { userId, targetUserId } = req.params;
    const db = getDatabase();
    const conversationId = [userId, targetUserId].sort().join(':');

    const conversation = await db.collection('conversations').findOne({ _id: conversationId });
    res.json({ success: true, data: conversation || null });
  } catch (error) {
    console.error('Get conversation metadata error:', error);
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

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      _id: new ObjectId(),
      conversationId,
      fromUserId: new ObjectId(fromUserId),
      fromUserRole: 'teacher',
      toUserId: new ObjectId(toUserId),
      toUserRole: toUserRole || 'student',
      message: message,
      timestamp: new Date().toISOString(),
      isRead: false,
      createdAt: new Date().toISOString()
    };

    await db.collection('chat_messages').insertOne(chatMessage);

    res.status(201).json({ success: true, data: chatMessage });
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

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      _id: new ObjectId(),
      conversationId,
      fromUserId: new ObjectId(fromUserId),
      fromUserRole: 'admin',
      toUserId: new ObjectId(toUserId),
      toUserRole: toUserRole || 'student',
      message: message,
      timestamp: new Date().toISOString(),
      isRead: false,
      createdAt: new Date().toISOString()
    };

    await db.collection('chat_messages').insertOne(chatMessage);

    // When an admin replies, mark all unread student messages as read for this student
    await db.collection('chat_messages').updateMany(
      {
        fromUserId: new ObjectId(toUserId),
        fromUserRole: 'student',
        isRead: false
      },
      {
        $set: { isRead: true, answeredBy: new ObjectId(fromUserId), answeredAt: new Date().toISOString() }
      }
    );

    res.status(201).json({ success: true, data: chatMessage });
  } catch (error) {
    console.error('Send admin message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversation = async (req, res) => {
  try {
    const { userId, targetUserId } = req.query;
    const db = getDatabase();

    // Only return messages from the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const conversationId = [userId, targetUserId].sort().join(':');
    const messages = await db.collection('chat_messages')
      .find({
        conversationId,
        timestamp: { $gte: thirtyDaysAgo.toISOString() }
      })
      .sort({ timestamp: 1 })
      .toArray();

    res.json({ success: true, data: messages });
  } catch (error) {
    console.error('Get conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getAllConversations = async (req, res) => {
  try {
    const db = getDatabase();

    // Distinct conversationIds and derive a studentId for each
    const conversationIds = await db.collection('chat_messages').distinct('conversationId');
    const conversations = await Promise.all(conversationIds.map(async (convId) => {
      const lastMessage = await db.collection('chat_messages')
        .find({ conversationId: convId })
        .sort({ timestamp: -1 })
        .limit(1)
        .toArray()
        .then(arr => arr[0] || null);

      if (!lastMessage) {
        return null;
      }

      // Extract the studentId from the conversation by inspecting the last message roles
      const studentId = (lastMessage.fromUserRole === 'student'
        ? lastMessage.fromUserId
        : (lastMessage.toUserRole === 'student' ? lastMessage.toUserId : null));

      if (!studentId) return null;

      const unreadCount = await db.collection('chat_messages')
        .countDocuments({
          conversationId: convId,
          fromUserRole: 'student',
          isRead: false
        });

      return {
        conversationId: convId,
        studentId: studentId.toString(),
        lastMessage,
        unreadCount,
      };
    }));

    res.json({ success: true, data: conversations.filter(Boolean) });
  } catch (error) {
    console.error('Get all conversations error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getUnreadMessages = async (req, res) => {
  try {
    const db = getDatabase();
    const unread = await db.collection('chat_messages')
      .find({ fromUserRole: 'student', isRead: false })
      .sort({ timestamp: -1 })
      .toArray();
    res.json({ success: true, data: unread });
  } catch (error) {
    console.error('Get unread messages error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getDefaultAdmin = async (req, res) => {
  try {
    const db = getDatabase();
    // Try to find the most recent active admin from chat history
    const recentAdminMessage = await db.collection('chat_messages')
      .find({ fromUserRole: 'admin' })
      .sort({ timestamp: -1 })
      .limit(1)
      .toArray()
      .then(arr => arr[0] || null);

    if (recentAdminMessage) {
      return res.json({ success: true, adminId: recentAdminMessage.fromUserId.toString() });
    }

    // Fallback: look for any admin who has ever received chat
    const anyAdmin = await db.collection('chat_messages')
      .find({ toUserRole: 'admin' })
      .limit(1)
      .toArray()
      .then(arr => arr[0] || null);

    if (anyAdmin) {
      return res.json({ success: true, adminId: anyAdmin.toUserId.toString() });
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

    await db.collection('chat_messages').updateMany(
      {
        fromUserId: new ObjectId(studentId),
        fromUserRole: 'student',
        isRead: false
      },
      { $set: { isRead: true, readAt: new Date().toISOString() } }
    );

    res.json({ success: true, message: 'Messages marked as read' });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

