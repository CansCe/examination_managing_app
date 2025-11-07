import 'dart:async';
import 'api_service.dart';

class ChatMessage {
  final String id; // Changed from ObjectId to String (UUID)
  final String fromUserId;
  final String fromUserRole; // 'student', 'teacher', or 'admin'
  final String toUserId;
  final String toUserRole;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? conversationId;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.fromUserRole,
    required this.toUserId,
    required this.toUserRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.conversationId,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Handle both MongoDB format (_id) and Supabase format (id)
    String messageId = map['id'] ?? map['_id']?.toString() ?? '';
    
    // Helper to convert any ID format to string
    String convertToString(dynamic value) {
      if (value is String) return value;
      if (value != null) return value.toString();
      return '';
    }

    return ChatMessage(
      id: messageId,
      fromUserId: convertToString(map['from_user_id'] ?? map['fromUserId']),
      fromUserRole: map['from_user_role'] ?? map['fromUserRole'] ?? 'student',
      toUserId: convertToString(map['to_user_id'] ?? map['toUserId']),
      toUserRole: map['to_user_role'] ?? map['toUserRole'] ?? 'student',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] is DateTime 
          ? map['timestamp'] 
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: map['is_read'] ?? map['isRead'] ?? false,
      conversationId: map['conversation_id'] ?? map['conversationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'from_user_role': fromUserRole,
      'to_user_id': toUserId,
      'to_user_role': toUserRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'conversation_id': conversationId,
    };
  }

  // Backward-compatibility getters used by older UI code
  String get studentId => fromUserRole == 'student' ? fromUserId : toUserId;
  String get sender => fromUserRole;
}

class ChatSocketService {
  dynamic _channel; // No longer using RealtimeChannel, kept for compatibility
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<List<ChatMessage>> _historyController = StreamController<List<ChatMessage>>.broadcast();
  bool _isConnected = false;
  String? _conversationId;

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<List<ChatMessage>> get historyStream => _historyController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the chat using REST API (Realtime disabled)
  Future<void> connect({
    required String userId,
    required String userRole,
    required String targetUserId,
    required String targetUserRole,
  }) async {
    // Disconnect existing connection
    if (_channel != null) {
      await disconnect();
    }

    final sortedIds = [userId, targetUserId]..sort();
    _conversationId = sortedIds.join(':');
    final conversationId = _conversationId!;

    print('Connecting to chat service for conversation: $conversationId');

    try {
      _isConnected = true;
      print('✓ Connected to chat service (REST API)');
      
      // Load chat history
      await _loadChatHistory(userId, targetUserId);
      
      // Start polling for new messages every 3 seconds
      _startPolling(userId, targetUserId);
    } catch (e) {
      _isConnected = false;
      print('✗ Error connecting to chat service: $e');
      rethrow;
    }
  }

  Timer? _pollingTimer;
  DateTime? _lastMessageTimestamp; // Track last message timestamp to avoid duplicates
  final Set<String> _seenMessageIds = {}; // Track all seen message IDs
  
  void _startPolling(String userId, String targetUserId) {
    // Stop any existing polling
    _pollingTimer?.cancel();
    
    // Poll every 3 seconds for new messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      
      try {
        final api = ApiService();
        final messages = await api.getChatMessages(
          userId: userId,
          targetUserId: targetUserId,
        );
        final chatMessages = messages
            .map((m) => ChatMessage.fromMap(m))
            .toList();
        
        // Only add new messages that we haven't seen before
        for (final msg in chatMessages) {
          // Skip if we've already seen this message
          if (_seenMessageIds.contains(msg.id)) {
            continue;
          }
          
          // Only add messages that are newer than the last one we saw
          if (_lastMessageTimestamp == null || 
              msg.timestamp.isAfter(_lastMessageTimestamp!)) {
            _messageController.add(msg);
            _seenMessageIds.add(msg.id);
            _lastMessageTimestamp = msg.timestamp;
          }
        }
        
        api.close();
      } catch (e) {
        print('Error polling for messages: $e');
      }
    });
  }

  /// Load chat history from REST API
  Future<void> _loadChatHistory(String userId, String targetUserId) async {
    try {
      final api = ApiService();
      final messages = await api.getChatMessages(
        userId: userId,
        targetUserId: targetUserId,
      );
      final chatMessages = messages
          .map((m) => ChatMessage.fromMap(m))
          .toList();
      _historyController.add(chatMessages);
      
      // Set last message timestamp and track seen IDs for polling
      if (chatMessages.isNotEmpty) {
        _lastMessageTimestamp = chatMessages.last.timestamp;
        _seenMessageIds.addAll(chatMessages.map((m) => m.id));
      }
      
      api.close();
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  /// Send a message via REST API
  Future<void> sendMessage({
    required String message,
    required String fromUserId,
    required String fromUserRole,
    required String toUserId,
    required String toUserRole,
  }) async {
    final api = ApiService();
    try {
      Map<String, dynamic> response;
      
      // Call the appropriate REST API endpoint based on user role
      if (fromUserRole == 'student') {
        response = await api.sendStudentMessage(
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: message,
          toUserRole: toUserRole,
        );
      } else if (fromUserRole == 'teacher') {
        response = await api.sendTeacherMessage(
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: message,
          toUserRole: toUserRole,
        );
      } else if (fromUserRole == 'admin') {
        response = await api.sendAdminMessage(
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: message,
          toUserRole: toUserRole,
        );
      } else {
        throw Exception('Invalid user role: $fromUserRole');
      }

      // Convert response to ChatMessage and add to stream
      final chatMessage = ChatMessage.fromMap(response);
      _messageController.add(chatMessage);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    } finally {
      api.close();
    }
  }

  /// Mark messages as read (using REST API)
  Future<void> markAsRead(String userId, String targetUserId) async {
    // Note: This would require a REST API endpoint for marking messages as read
    // For now, we'll leave this as a placeholder since the backend has PUT /api/chat/read/:studentId
    // but it's designed for admin marking student messages as read
    print('Mark as read not yet implemented via REST API');
  }

  /// Disconnect from chat
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_channel != null) {
      _channel = null;
    }
    _isConnected = false;
    _conversationId = null;
  }

  /// Get messages via REST API (fallback when Realtime is not available)
  Future<List<ChatMessage>> getMessages({
    required String userId,
    required String targetUserId,
  }) async {
    try {
      final apiService = ApiService();
      final messagesData = await apiService.getChatMessages(
        userId: userId,
        targetUserId: targetUserId,
      );
      apiService.close();

      return messagesData
          .map((data) => ChatMessage.fromMap(data))
          .toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _historyController.close();
  }
}

/// Legacy ChatService for backward compatibility and REST API methods
class ChatService {
  /// Get messages between two users using REST API
  static Future<List<ChatMessage>> getMessages({
    required String userId,
    required String targetUserId,
  }) async {
    try {
      final apiService = ApiService();
      final messagesData = await apiService.getChatMessages(
        userId: userId,
        targetUserId: targetUserId,
      );
      apiService.close();

      return messagesData
          .map((data) => ChatMessage.fromMap(data))
          .toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  /// Get conversation messages (alias for getMessages for backward compatibility)
  static Future<List<ChatMessage>> getConversation({
    required String userId,
    required String targetUserId,
  }) async {
    return getMessages(userId: userId, targetUserId: targetUserId);
  }

  /// Get messages for a student (backward compatibility - use getMessages instead)
  static Future<List<ChatMessage>> getStudentMessages(String studentId) async {
    throw UnimplementedError('Use ChatService.getMessages(userId, targetUserId) instead');
  }

  static Future<void> sendStudentMessage({
    required String studentId,
    required String message,
  }) async {
    throw UnimplementedError('Use ChatSocketService instead');
  }

  static Future<void> sendAdminMessage({
    required String studentId,
    required String adminId,
    required String message,
  }) async {
    throw UnimplementedError('Use ChatSocketService instead');
  }

  static Future<void> markAsRead(String studentId) async {
    throw UnimplementedError('Use ChatSocketService instead');
  }

  // Temporary compatibility methods used by AdminChatPage
  static Future<List<ChatMessage>> getUnreadMessages() async {
    try {
      final api = ApiService();
      final data = await api.getUnreadChatMessages();
      api.close();
      return data.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching unread messages: $e');
      return [];
    }
  }

  static Future<List<String>> getStudentsWithChatHistory() async {
    try {
      final api = ApiService();
      final data = await api.getChatConversations();
      api.close();
      return data
        .map((c) => (c['studentId'] ?? (c['student']?['id']))?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    } catch (e) {
      print('Error fetching students with chat history: $e');
      return [];
    }
  }
}
