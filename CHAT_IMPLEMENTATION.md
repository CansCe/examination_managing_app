# Real-Time Chat Implementation

## Overview
Implemented a real-time chat system using **WebSocket (Socket.IO)** for minimal latency communication between students, teachers, and admins. Messages are stored in MongoDB and only messages from the last 30 days are shown/stored.

## Features Implemented

### ✅ Real-Time Communication
- **Protocol**: WebSocket using Socket.IO (best for minimal latency)
- **Latency**: Messages appear instantly (no polling delays)
- **Connection**: Persistent WebSocket connection with automatic reconnection

### ✅ Multi-Role Support
- Students can chat with admins and teachers
- Teachers can chat with students and admins
- Admins can chat with students and teachers
- All conversations are properly routed based on user roles

### ✅ Message Persistence
- All messages stored in MongoDB (`chat_messages` collection)
- Messages accessible from any device when logged in
- Cross-device synchronization

### ✅ 30-Day Retention Policy
- Only messages from the last 30 days are:
  - Shown in chat history
  - Stored in database
- Automatic cleanup of old messages (runs every 24 hours)

## Architecture

### Backend (Node.js/Express)
- **WebSocket Server**: `backend-api/sockets/chat.socket.js`
- **Socket.IO**: Handles real-time bidirectional communication
- **Message Storage**: MongoDB with automatic cleanup
- **Room Management**: Each conversation has a unique room ID

### Frontend (Flutter)
- **WebSocket Client**: `lib/services/chat_service.dart`
- **ChatSocketService**: Manages WebSocket connections
- **Real-Time Updates**: Stream-based message handling
- **UI Components**: Updated chat pages use WebSocket instead of polling

## Files Changed

### Backend
1. `backend-api/package.json` - Added socket.io dependency
2. `backend-api/server.js` - Set up HTTP server with Socket.IO
3. `backend-api/sockets/chat.socket.js` - **NEW** WebSocket handlers
4. `backend-api/controllers/chat.controller.js` - Updated for new message structure
5. `backend-api/routes/chat.routes.js` - Added teacher endpoint

### Frontend
1. `pubspec.yaml` - Added socket_io_client dependency
2. `lib/services/chat_service.dart` - **REWRITTEN** WebSocket client service
3. `lib/features/shared/helpdesk_chat.dart` - Updated to use WebSocket
4. `lib/features/admin/admin_chat_page.dart` - Updated to use WebSocket

## New Message Model

```dart
ChatMessage {
  id: ObjectId
  fromUserId: String
  fromUserRole: 'student' | 'teacher' | 'admin'
  toUserId: String
  toUserRole: 'student' | 'teacher' | 'admin'
  message: String
  timestamp: DateTime
  isRead: bool
}
```

## Usage

### Connecting to Chat
```dart
final chatService = ChatSocketService();
chatService.connect(
  userId: 'user_id_here',
  userRole: 'student', // or 'teacher' or 'admin'
  targetUserId: 'target_user_id',
  targetUserRole: 'admin',
);
```

### Sending Messages
```dart
chatService.sendMessage(
  message: 'Hello!',
  fromUserId: 'user_id',
  fromUserRole: 'student',
  toUserId: 'target_id',
  toUserRole: 'admin',
);
```

### Listening for Messages
```dart
chatService.messageStream.listen((message) {
  // Handle new message
});

chatService.historyStream.listen((messages) {
  // Handle chat history
});
```

## Setup Instructions

### Backend
1. Install dependencies:
   ```bash
   cd backend-api
   npm install
   ```

2. Start the server:
   ```bash
   npm start
   ```

   The WebSocket server will be available at `ws://localhost:3000`

### Frontend
1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. The chat will automatically connect when opened

## Configuration

### WebSocket URL
The WebSocket URL is automatically derived from `ApiConfig.baseUrl`:
- `http://localhost:3000` → `ws://localhost:3000`
- `https://example.com` → `wss://example.com`

To override, pass `socketUrl` to `ChatSocketService` constructor.

## Benefits Over Polling

1. **Minimal Latency**: Messages appear instantly (< 100ms)
2. **Reduced Server Load**: No constant HTTP requests
3. **Better UX**: Real-time updates without refresh delays
4. **Efficient**: Bidirectional communication on single connection
5. **Scalable**: WebSocket handles many concurrent connections

## Testing

1. Start the backend server
2. Open the app on multiple devices/sessions
3. Send messages between different users
4. Verify messages appear instantly on all devices
5. Check that only last 30 days of messages are shown

## Notes

- Messages older than 30 days are automatically deleted
- Connection status is shown in the UI (green = connected, red = disconnected)
- Automatic reconnection on connection loss
- Messages are stored in MongoDB for persistence across sessions

