# Chat Service Usage Guide

This guide explains how to use the chat service in the Exam Management App, including Flutter integration examples and best practices.

## Overview

The chat service enables real-time messaging between students, teachers, and admins. It uses WebSocket (Socket.io) for real-time communication and HTTP REST API for message history.

## Flutter Integration

### Initialization

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:exam_management_app/services/chat_service.dart';

// Initialize chat service
final chatService = ChatService();
await chatService.initialize();
```

### Connect to Chat Service

```dart
// Connect to chat service
await chatService.connect();

// Check connection status
if (chatService.isConnected) {
  print('Connected to chat service');
}
```

### Disconnect

```dart
// Disconnect from chat service
await chatService.disconnect();
```

## Sending Messages

### Send Message as Student

```dart
try {
  final result = await chatService.sendStudentMessage(
    fromUserId: studentId,
    toUserId: adminId,
    toUserRole: 'admin',
    message: 'Hello, I need help with the exam',
  );
  
  if (result['success'] == true) {
    print('Message sent successfully');
  }
} catch (e) {
  print('Error sending message: $e');
}
```

### Send Message as Teacher

```dart
try {
  final result = await chatService.sendTeacherMessage(
    fromUserId: teacherId,
    toUserId: studentId,
    toUserRole: 'student',
    message: 'Your exam results are ready',
  );
  
  if (result['success'] == true) {
    print('Message sent successfully');
  }
} catch (e) {
  print('Error sending message: $e');
}
```

## Receiving Messages

### Listen for Real-Time Messages

```dart
// Set up message listener
chatService.onMessageReceived = (message) {
  print('New message received: ${message['message']}');
  print('From: ${message['from_user_id']}');
  print('Timestamp: ${message['timestamp']}');
  
  // Update UI with new message
  setState(() {
    messages.add(message);
  });
};

// Start listening
await chatService.startListening();
```

### Get Message History

```dart
// Get conversation messages
try {
  final messages = await chatService.getConversationMessages(
    conversationId: conversationId,
  );
  
  // Display messages in UI
  for (final message in messages) {
    print('${message['message']} - ${message['timestamp']}');
  }
} catch (e) {
  print('Error fetching messages: $e');
}
```

## Managing Conversations

### Get User Conversations

```dart
try {
  final conversations = await chatService.getUserConversations(
    userId: currentUserId,
  );
  
  // Display conversations list
  for (final conv in conversations) {
    print('Conversation: ${conv['conversation_id']}');
    print('Last message: ${conv['last_message']}');
  }
} catch (e) {
  print('Error fetching conversations: $e');
}
```

### Join Conversation Room

```dart
// Join a conversation room for real-time updates
await chatService.joinConversation(
  userId: currentUserId,
  conversationId: conversationId,
);
```

### Leave Conversation Room

```dart
// Leave a conversation room
await chatService.leaveConversation(
  conversationId: conversationId,
);
```

## Message Status

### Mark Messages as Read

```dart
try {
  await chatService.markMessagesAsRead(
    conversationId: conversationId,
    userId: currentUserId,
  );
} catch (e) {
  print('Error marking messages as read: $e');
}
```

### Check Unread Count

```dart
final unreadCount = await chatService.getUnreadMessageCount(
  userId: currentUserId,
);
print('Unread messages: $unreadCount');
```

## UI Integration Example

### Chat Screen Widget

```dart
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  
  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.currentUserId,
  }) : super(key: key);
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }
  
  Future<void> _initializeChat() async {
    // Initialize and connect
    await _chatService.initialize();
    await _chatService.connect();
    
    // Join conversation
    await _chatService.joinConversation(
      userId: widget.currentUserId,
      conversationId: widget.conversationId,
    );
    
    // Set up message listener
    _chatService.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
    };
    
    // Load message history
    await _loadMessages();
  }
  
  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getConversationMessages(
        conversationId: widget.conversationId,
      );
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    } catch (e) {
      print('Error loading messages: $e');
    }
  }
  
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    try {
      await _chatService.sendStudentMessage(
        fromUserId: widget.currentUserId,
        toUserId: 'admin_id_here',
        toUserRole: 'admin',
        message: _messageController.text.trim(),
      );
      
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  @override
  void dispose() {
    _chatService.disconnect();
    _messageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['from_user_id'] == widget.currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(message['timestamp']),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(String timestamp) {
    // Format timestamp for display
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
```

## Conversation ID Format

Conversation IDs are generated by sorting participant IDs:

```dart
String generateConversationId(String userId1, String userId2) {
  final sorted = [userId1, userId2]..sort();
  return '${sorted[0]}_${sorted[1]}';
}
```

This ensures the same conversation ID is used regardless of which user initiates.

## Error Handling

### Connection Errors

```dart
_chatService.onConnectionError = (error) {
  print('Connection error: $error');
  // Show error message to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Connection error: $error')),
  );
};
```

### Message Send Errors

```dart
try {
  await _chatService.sendStudentMessage(...);
} on SocketException catch (e) {
  print('Network error: $e');
} on FormatException catch (e) {
  print('Invalid data: $e');
} catch (e) {
  print('Unknown error: $e');
}
```

## Best Practices

### 1. Connection Management

- Connect when entering chat screen
- Disconnect when leaving chat screen
- Reconnect on app resume

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _chatService.reconnect();
  } else if (state == AppLifecycleState.paused) {
    _chatService.disconnect();
  }
}
```

### 2. Message Pagination

Load messages in batches for better performance:

```dart
Future<void> _loadMoreMessages() async {
  final moreMessages = await _chatService.getConversationMessages(
    conversationId: widget.conversationId,
    limit: 20,
    offset: _messages.length,
  );
  
  setState(() {
    _messages.insertAll(0, moreMessages);
  });
}
```

### 3. Timestamp Display

Format timestamps appropriately:

- Recent (< 1 hour): "Just now" or "X minutes ago"
- Today: "HH:MM"
- Yesterday: "Yesterday at HH:MM"
- This week: "Day at HH:MM"
- Older: "MM/DD/YYYY at HH:MM"

### 4. Read Status

Mark messages as read when viewed:

```dart
void _onMessageViewed() {
  _chatService.markMessagesAsRead(
    conversationId: widget.conversationId,
    userId: widget.currentUserId,
  );
}
```

### 5. Message Validation

Validate messages before sending:

```dart
bool _validateMessage(String message) {
  if (message.trim().isEmpty) return false;
  if (message.length > 1000) return false; // Max length
  return true;
}
```

## Troubleshooting

### Messages Not Sending

- Check chat service connection: `_chatService.isConnected`
- Verify user IDs are correct
- Check network connectivity
- Review service logs

### Messages Not Receiving

- Verify conversation room is joined
- Check message listener is set up
- Verify WebSocket connection
- Check service is running

### Connection Drops

- Implement reconnection logic
- Handle connection errors gracefully
- Show connection status to user
- Retry failed operations

## Next Steps

- Read [CHAT_IMPLEMENTATION.md](CHAT_IMPLEMENTATION.md) for implementation details
- Read [BACKEND_SETUP.md](BACKEND_SETUP.md) for backend setup
- Read [DEPLOYMENT.md](DEPLOYMENT.md) for deployment guide

---

**Last Updated**: 2024