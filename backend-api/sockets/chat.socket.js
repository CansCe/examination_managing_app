import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';

// Store active connections by user ID and role
const activeConnections = new Map();

// Clean up old messages (older than 30 days)
async function cleanupOldMessages() {
  try {
    const db = getDatabase();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const result = await db.collection('chat_messages').deleteMany({
      timestamp: { $lt: thirtyDaysAgo.toISOString() }
    });
    
    if (result.deletedCount > 0) {
      console.log(`Cleaned up ${result.deletedCount} old chat messages`);
    }
  } catch (error) {
    console.error('Error cleaning up old messages:', error);
  }
}

// Run cleanup every 24 hours
setInterval(cleanupOldMessages, 24 * 60 * 60 * 1000);

export function setupChatSocket(io) {
  io.on('connection', (socket) => {
    console.log(`Client connected: ${socket.id}`);

    // Handle user joining chat room
    socket.on('join_chat', async ({ userId, userRole, targetUserId, targetUserRole }) => {
      try {
        // Store connection info
        const connectionKey = `${userRole}:${userId}`;
        if (!activeConnections.has(connectionKey)) {
          activeConnections.set(connectionKey, new Set());
        }
        activeConnections.get(connectionKey).add(socket.id);

        // Create room/conversation ID (sorted to ensure same room for both participants)
        const roomId = [userId, targetUserId].sort().join(':');
        socket.join(roomId);
        
        socket.data.userId = userId;
        socket.data.userRole = userRole;
        socket.data.targetUserId = targetUserId;
        socket.data.targetUserRole = targetUserRole;
        socket.data.roomId = roomId;

        console.log(`${userRole} ${userId} joined room ${roomId}`);

        // Load and send last 30 days of messages
        const db = getDatabase();
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const messages = await db.collection('chat_messages')
          .find({
            conversationId: roomId,
            timestamp: { $gte: thirtyDaysAgo.toISOString() }
          })
          .sort({ timestamp: 1 })
          .toArray();

        socket.emit('chat_history', { messages });
      } catch (error) {
        console.error('Error joining chat:', error);
        socket.emit('error', { message: 'Failed to join chat' });
      }
    });

    // Handle sending a message
    socket.on('send_message', async ({ message, fromUserId, fromUserRole, toUserId, toUserRole }) => {
      try {
        const db = getDatabase();
        const now = new Date();

        const roomId = [fromUserId, toUserId].sort().join(':');
        const chatMessage = {
          _id: new ObjectId(),
          conversationId: roomId,
          fromUserId: new ObjectId(fromUserId),
          fromUserRole: fromUserRole,
          toUserId: new ObjectId(toUserId),
          toUserRole: toUserRole,
          message: message,
          timestamp: now.toISOString(),
          isRead: false,
          createdAt: now.toISOString()
        };

        // Save to database
        await db.collection('chat_messages').insertOne(chatMessage);

        // Emit to all clients in the room
        io.to(roomId).emit('new_message', {
          message: chatMessage
        });

        console.log(`Message sent from ${fromUserRole} ${fromUserId} to ${toUserRole} ${toUserId}`);
      } catch (error) {
        console.error('Error sending message:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Handle marking messages as read
    socket.on('mark_read', async ({ userId, targetUserId }) => {
      try {
        const db = getDatabase();
        await db.collection('chat_messages').updateMany(
          {
            fromUserId: new ObjectId(targetUserId),
            toUserId: new ObjectId(userId),
            isRead: false
          },
          {
            $set: { 
              isRead: true, 
              readAt: new Date().toISOString() 
            }
          }
        );

        // Notify other user that messages were read
        const roomId = [userId, targetUserId].sort().join(':');
        io.to(roomId).emit('messages_read', { userId, targetUserId });
      } catch (error) {
        console.error('Error marking messages as read:', error);
      }
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      console.log(`Client disconnected: ${socket.id}`);
      
      // Remove from active connections
      if (socket.data.userId && socket.data.userRole) {
        const connectionKey = `${socket.data.userRole}:${socket.data.userId}`;
        const connections = activeConnections.get(connectionKey);
        if (connections) {
          connections.delete(socket.id);
          if (connections.size === 0) {
            activeConnections.delete(connectionKey);
          }
        }
      }
    });

    // Handle errors
    socket.on('error', (error) => {
      console.error('Socket error:', error);
    });
  });

  console.log('✓ Chat WebSocket handlers initialized');
}

