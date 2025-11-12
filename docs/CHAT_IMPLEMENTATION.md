# Chat Implementation Guide

This document describes the chat service implementation for the Exam Management App.

## Overview

The chat service provides real-time messaging between students, teachers, and admins using WebSocket (Socket.io) and MongoDB for message persistence.

## Architecture

- **Technology**: Node.js + Express + Socket.io
- **Database**: MongoDB
- **Port**: 3001
- **Protocol**: WebSocket (Socket.io) for real-time, HTTP REST for message history

## Features

- Real-time messaging via WebSocket
- Message persistence in MongoDB
- One-on-one conversations
- Support for students, teachers, and admins
- Automatic cleanup of messages older than 30 days
- Timestamp display for messages
- Read/unread status tracking

## Database Schema

### Messages Collection

```javascript
{
  _id: ObjectId,
  conversationId: String,      // Unique conversation identifier
  senderId: ObjectId,          // User ID (student, teacher, or admin)
  receiverId: ObjectId,         // User ID (student, teacher, or admin)
  message: String,              // Message content
  timestamp: Date,               // Message timestamp
  read: Boolean,                 // Read status
  createdAt: Date
}
```

### Conversations Collection

```javascript
{
  _id: ObjectId,
  participants: [ObjectId],     // Array of user IDs
  lastMessage: String,           // Last message preview
  lastMessageTime: Date,         // Last message timestamp
  createdAt: Date,
  updatedAt: Date
}
```

## API Endpoints

### Health Check

```
GET /health
```

Returns service status.

### Get Conversations

```
GET /api/chat/conversations/:userId
```

Returns all conversations for a user.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "_id": "...",
      "participants": ["userId1", "userId2"],
      "lastMessage": "Hello",
      "lastMessageTime": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### Get Messages

```
GET /api/chat/messages/:conversationId
```

Returns messages for a conversation.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "_id": "...",
      "conversationId": "conv123",
      "senderId": "userId1",
      "receiverId": "userId2",
      "message": "Hello",
      "timestamp": "2024-01-01T00:00:00Z",
      "read": false
    }
  ]
}
```

## WebSocket Events

### Client → Server

#### Join Room
```javascript
socket.emit('join_room', {
  userId: 'userId123',
  conversationId: 'conv123'
});
```

#### Send Message
```javascript
socket.emit('send_message', {
  conversationId: 'conv123',
  senderId: 'userId1',
  receiverId: 'userId2',
  message: 'Hello, how are you?'
});
```

#### Mark as Read
```javascript
socket.emit('mark_read', {
  conversationId: 'conv123',
  userId: 'userId2'
});
```

### Server → Client

#### Message Received
```javascript
socket.on('message_received', (data) => {
  console.log('New message:', data);
  // data: { conversationId, senderId, receiverId, message, timestamp }
});
```

#### Message Sent
```javascript
socket.on('message_sent', (data) => {
  console.log('Message sent:', data);
  // data: { conversationId, messageId, timestamp }
});
```

## Flutter Integration

### Connect to Chat Service

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io('http://localhost:3001', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': false,
});

socket.connect();
```

### Join Conversation

```dart
socket.emit('join_room', {
  'userId': userId,
  'conversationId': conversationId,
});
```

### Send Message

```dart
socket.emit('send_message', {
  'conversationId': conversationId,
  'senderId': senderId,
  'receiverId': receiverId,
  'message': messageText,
});
```

### Listen for Messages

```dart
socket.on('message_received', (data) {
  // Handle new message
  final message = Message.fromMap(data);
  // Update UI
});
```

## Message Cleanup

The chat service includes an automatic cleanup script that removes messages older than 30 days.

### Manual Cleanup

```bash
cd backend-chat
node scripts/cleanup-old-messages.js
```

### Automated Cleanup

Set up a cron job or scheduled task:

```bash
# Run daily at 2 AM
0 2 * * * cd /path/to/backend-chat && node scripts/cleanup-old-messages.js
```

## Conversation ID Generation

Conversation IDs are generated based on participant IDs:

```javascript
function generateConversationId(userId1, userId2) {
  const sorted = [userId1, userId2].sort();
  return `${sorted[0]}_${sorted[1]}`;
}
```

This ensures the same conversation ID is used regardless of which user initiates.

## Timestamp Display

Messages include timestamps that can be displayed in the UI:

- **Recent messages** (< 1 hour): "Just now" or "X minutes ago"
- **Today**: "HH:MM" format
- **Yesterday**: "Yesterday at HH:MM"
- **This week**: "Day at HH:MM"
- **Older**: "MM/DD/YYYY at HH:MM"

## Security

### Rate Limiting

Chat endpoints are protected with rate limiting:
- Message sending: 20 requests per 15 minutes
- Conversation fetching: 100 requests per 15 minutes

### Input Validation

All message inputs are validated and sanitized:
- Message length limits
- XSS prevention
- SQL injection prevention (NoSQL injection)

### CORS Configuration

CORS is configured to allow only specified origins. Update `ALLOWED_ORIGINS` in `.env` file.

## Error Handling

### Connection Errors

```javascript
socket.on('connect_error', (error) => {
  console.error('Connection error:', error);
});
```

### Message Errors

```javascript
socket.on('error', (error) => {
  console.error('Socket error:', error);
});
```

## Testing

### Test WebSocket Connection

```bash
# Using wscat
npm install -g wscat
wscat -c ws://localhost:3001/socket.io/?transport=websocket
```

### Test HTTP Endpoints

```bash
# Health check
curl http://localhost:3001/health

# Get conversations
curl http://localhost:3001/api/chat/conversations/userId123

# Get messages
curl http://localhost:3001/api/chat/messages/conv123
```

## Troubleshooting

### WebSocket Connection Fails

- Check chat service is running: `curl http://localhost:3001/health`
- Verify CORS configuration
- Check firewall rules
- Verify WebSocket support in network

### Messages Not Persisting

- Check MongoDB connection
- Verify database permissions
- Check service logs

### Messages Not Delivered

- Verify both users are connected
- Check conversation ID matches
- Verify room joining

## Performance Considerations

- **Message Pagination**: Implement pagination for message history
- **Connection Pooling**: Use MongoDB connection pooling
- **Message Batching**: Batch multiple messages if needed
- **Indexing**: Index `conversationId` and `timestamp` fields
