import { getDatabase } from '../config/database.js';
import { validationResult } from 'express-validator';
import { isValidUuid } from '../utils/supabase-helpers.js';

export const sendStudentMessage = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { fromUserId, toUserId, toUserRole, message } = req.body;
    const supabase = getDatabase();

    if (!isValidUuid(fromUserId) || !isValidUuid(toUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: fromUserId,
      from_user_role: 'student',
      to_user_id: toUserId,
      to_user_role: toUserRole || 'admin',
      message: message,
      is_read: false
    };

    const { data, error } = await supabase
      .from('chat_messages')
      .insert(chatMessage)
      .select()
      .single();

    if (error) {
      console.error('Send student message error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.status(201).json({ success: true, data });
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
    const supabase = getDatabase();

    if (!isValidUuid(fromUserId) || !isValidUuid(toUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: fromUserId,
      from_user_role: 'teacher',
      to_user_id: toUserId,
      to_user_role: toUserRole || 'student',
      message: message,
      is_read: false
    };

    const { data, error } = await supabase
      .from('chat_messages')
      .insert(chatMessage)
      .select()
      .single();

    if (error) {
      console.error('Send teacher message error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.status(201).json({ success: true, data });
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
    const supabase = getDatabase();

    if (!isValidUuid(fromUserId) || !isValidUuid(toUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const conversationId = [fromUserId, toUserId].sort().join(':');
    const chatMessage = {
      conversation_id: conversationId,
      from_user_id: fromUserId,
      from_user_role: 'admin',
      to_user_id: toUserId,
      to_user_role: toUserRole || 'student',
      message: message,
      is_read: false
    };

    const { data, error } = await supabase
      .from('chat_messages')
      .insert(chatMessage)
      .select()
      .single();

    if (error) {
      console.error('Send admin message error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    // When an admin replies, mark all unread student messages as read for this student
    await supabase
      .from('chat_messages')
      .update({
        is_read: true,
        answered_by: fromUserId,
        answered_at: new Date().toISOString()
      })
      .eq('from_user_id', toUserId)
      .eq('from_user_role', 'student')
      .eq('is_read', false);

    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('Send admin message error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversation = async (req, res) => {
  try {
    const { userId, targetUserId } = req.query;
    const supabase = getDatabase();

    if (!isValidUuid(userId) || !isValidUuid(targetUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    // Only return messages from the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const conversationId = [userId, targetUserId].sort().join(':');
    const { data: messages, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .gte('timestamp', thirtyDaysAgo.toISOString())
      .order('timestamp', { ascending: true });

    if (error) {
      console.error('Get conversation error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.json({ success: true, data: messages || [] });
  } catch (error) {
    console.error('Get conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getAllConversations = async (req, res) => {
  try {
    const supabase = getDatabase();

    // Get distinct conversation IDs from last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { data: messages, error } = await supabase
      .from('chat_messages')
      .select('conversation_id, from_user_id, from_user_role, to_user_id, to_user_role, timestamp, is_read')
      .gte('timestamp', thirtyDaysAgo.toISOString())
      .order('timestamp', { ascending: false });

    if (error) {
      console.error('Get all conversations error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    // Group by conversation_id and get last message
    const conversationsMap = new Map();
    messages?.forEach(msg => {
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

        const { count } = await supabase
          .from('chat_messages')
          .select('*', { count: 'exact', head: true })
          .eq('conversation_id', conv.conversationId)
          .eq('from_user_role', 'student')
          .eq('is_read', false);

        return {
          ...conv,
          unreadCount: count || 0
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
    const supabase = getDatabase();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { data: unread, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('from_user_role', 'student')
      .eq('is_read', false)
      .gte('timestamp', thirtyDaysAgo.toISOString())
      .order('timestamp', { ascending: false });

    if (error) {
      console.error('Get unread messages error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.json({ success: true, data: unread || [] });
  } catch (error) {
    console.error('Get unread messages error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getDefaultAdmin = async (req, res) => {
  try {
    const supabase = getDatabase();
    
    // Fallback to configured default admin if provided
    const envAdmin = process.env.DEFAULT_ADMIN_ID;
    if (envAdmin && isValidUuid(envAdmin)) {
      return res.json({ success: true, adminId: envAdmin });
    }

    // Try to find the most recent active admin from chat history
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { data: recentAdminMessage } = await supabase
      .from('chat_messages')
      .select('from_user_id')
      .eq('from_user_role', 'admin')
      .gte('timestamp', thirtyDaysAgo.toISOString())
      .order('timestamp', { ascending: false })
      .limit(1)
      .single();

    if (recentAdminMessage) {
      return res.json({ success: true, adminId: recentAdminMessage.from_user_id });
    }

    // Fallback: look for any admin who has ever received chat
    const { data: anyAdmin } = await supabase
      .from('chat_messages')
      .select('to_user_id')
      .eq('to_user_role', 'admin')
      .limit(1)
      .single();

    if (anyAdmin) {
      return res.json({ success: true, adminId: anyAdmin.to_user_id });
    }

    // Fallback 3: pick any user with admin role
    const { data: adminUser } = await supabase
      .from('users')
      .select('id')
      .eq('role', 'admin')
      .limit(1)
      .single();

    if (adminUser) {
      return res.json({ success: true, adminId: adminUser.id });
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
    const supabase = getDatabase();

    if (!isValidUuid(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid student ID' });
    }

    const { error } = await supabase
      .from('chat_messages')
      .update({
        is_read: true,
        read_at: new Date().toISOString()
      })
      .eq('from_user_id', studentId)
      .eq('from_user_role', 'student')
      .eq('is_read', false);

    if (error) {
      console.error('Mark as read error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.json({ success: true, message: 'Messages marked as read' });
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
    const supabase = getDatabase();

    if (!isValidUuid(userId) || !isValidUuid(targetUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const conversationId = [userId, targetUserId].sort().join(':');

    // Delete messages
    const { count } = await supabase
      .from('chat_messages')
      .delete({ count: 'exact' })
      .eq('conversation_id', conversationId);

    // Update conversation metadata
    const conversationData = {
      id: conversationId,
      participant_1: userId < targetUserId ? userId : targetUserId,
      participant_2: userId < targetUserId ? targetUserId : userId,
      status: 'closed',
      closed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      ...(topic && { topic }),
      ...(priority && { priority }),
      ...(assignedAdmin && isValidUuid(assignedAdmin) && { assigned_admin: assignedAdmin })
    };

    const { error: convError } = await supabase
      .from('conversations')
      .upsert(conversationData, { onConflict: 'id' });

    if (convError) {
      console.error('Close conversation error:', convError);
    }

    res.json({ success: true, deleted: count || 0 });
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

    if (!isValidUuid(userId) || !isValidUuid(targetUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const supabase = getDatabase();
    const conversationId = [userId, targetUserId].sort().join(':');

    const conversationData = {
      id: conversationId,
      participant_1: userId < targetUserId ? userId : targetUserId,
      participant_2: userId < targetUserId ? targetUserId : userId,
      updated_at: new Date().toISOString(),
      ...(topic && { topic }),
      ...(priority && { priority }),
      ...(assignedAdmin && isValidUuid(assignedAdmin) && { assigned_admin: assignedAdmin })
    };

    const { data: conversation, error } = await supabase
      .from('conversations')
      .upsert(conversationData, { onConflict: 'id' })
      .select()
      .single();

    if (error) {
      console.error('Create/update conversation error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.json({ success: true, data: conversation });
  } catch (error) {
    console.error('Create/update conversation error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getConversationMetadata = async (req, res) => {
  try {
    const { userId, targetUserId } = req.params;
    const supabase = getDatabase();

    if (!isValidUuid(userId) || !isValidUuid(targetUserId)) {
      return res.status(400).json({ success: false, error: 'Invalid user IDs' });
    }

    const conversationId = [userId, targetUserId].sort().join(':');
    const { data: conversation, error } = await supabase
      .from('conversations')
      .select('*')
      .eq('id', conversationId)
      .single();

    if (error && error.code !== 'PGRST116') {
      console.error('Get conversation metadata error:', error);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }

    res.json({ success: true, data: conversation || null });
  } catch (error) {
    console.error('Get conversation metadata error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

