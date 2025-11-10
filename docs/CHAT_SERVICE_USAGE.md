# Chat Service Usage Guide

## Getting Messages

### Using ChatSocketService (Real-time WebSocket)

The `ChatSocketService` automatically loads messages when you connect, but you can also fetch them manually:

```dart
final chatService = ChatSocketService();

// Connect to chat (automatically loads last 30 days of messages)
chatService.connect(
  userId: 'user_id',
  userRole: 'student',
  targetUserId: 'target_user_id',
  targetUserRole: 'admin',
);

// Listen for chat history (loaded automatically on connect)
chatService.historyStream.listen((messages) {
  print('Loaded ${messages.length} messages');
  // messages is a List<ChatMessage>
});

// Or fetch messages manually using REST API (fallback)
final messages = await chatService.getMessages(
  userId: 'user_id',
  targetUserId: 'target_user_id',
);
```

### Using ChatService (REST API only)

For fetching messages without WebSocket connection:

```dart
// Get messages between two users
final messages = await ChatService.getMessages(
  userId: 'user_id',
  targetUserId: 'target_user_id',
);

// Or use the alias method
final messages = await ChatService.getConversation(
  userId: 'user_id',
  targetUserId: 'target_user_id',
);
```

## Example: Loading Messages in UI

```dart
class ChatPage extends StatefulWidget {
  final String userId;
  final String targetUserId;
  
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  ChatSocketService? _chatService;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  // Option 1: Use WebSocket (recommended for real-time)
  void _initializeWebSocket() {
    _chatService = ChatSocketService();
    _chatService!.connect(
      userId: widget.userId,
      userRole: 'student',
      targetUserId: widget.targetUserId,
      targetUserRole: 'admin',
    );

    // Listen for history
    _chatService!.historyStream.listen((messages) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    });

    // Listen for new messages
    _chatService!.messageStream.listen((message) {
      setState(() {
        if (!_messages.any((m) => m.id.toHexString() == message.id.toHexString())) {
          _messages.add(message);
        }
      });
    });
  }

  // Option 2: Use REST API (fallback or initial load)
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final messages = await ChatService.getMessages(
        userId: widget.userId,
        targetUserId: widget.targetUserId,
      );
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
  }

  @override
  void dispose() {
    _chatService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ListTile(
          title: Text(msg.message),
          subtitle: Text(msg.timestamp.toString()),
        );
      },
    );
  }
}
```

## API Endpoint

The backend endpoint is:
```
GET /api/chat/conversation?userId={userId}&targetUserId={targetUserId}
```

Returns:
```json
{
  "success": true,
  "data": [
    {
      "_id": "message_id",
      "fromUserId": "user_id",
      "fromUserRole": "student",
      "toUserId": "target_user_id",
      "toUserRole": "admin",
      "message": "Hello!",
      "timestamp": "2024-01-01T12:00:00.000Z",
      "isRead": false
    }
  ]
}
```

## Notes

- Messages are automatically filtered to last 30 days
- Both `userId` and `targetUserId` are required
- Messages are sorted by timestamp (oldest first)
- The method handles ObjectId conversion automatically

