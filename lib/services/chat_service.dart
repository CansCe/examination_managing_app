import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import '../config/api_config.dart';

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

class ChatMessage {
  final String id;
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
    // Handle MongoDB format (_id) and other formats
    String messageId = map['id'] ?? map['_id']?.toString() ?? '';
    
    // Helper to convert any ID format to string
    String convertToString(dynamic value) {
      if (value is String) return value;
      if (value != null) return value.toString();
      return '';
    }

    // Handle timestamp - can be DateTime, String (ISO), or Map
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) {
        try {
          return DateTime.parse(timestamp);
        } catch (e) {
          return DateTime.now();
        }
      }
      if (timestamp is Map && timestamp.containsKey('\$date')) {
        // MongoDB date format
        return DateTime.fromMillisecondsSinceEpoch(timestamp['\$date'] as int);
      }
      return DateTime.now();
    }

    return ChatMessage(
      id: messageId,
      fromUserId: convertToString(map['from_user_id'] ?? map['fromUserId']),
      fromUserRole: map['from_user_role'] ?? map['fromUserRole'] ?? 'student',
      toUserId: convertToString(map['to_user_id'] ?? map['toUserId']),
      toUserRole: map['to_user_role'] ?? map['toUserRole'] ?? 'student',
      message: map['message'] ?? '',
      timestamp: parseTimestamp(map['timestamp'] ?? map['createdAt']),
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
  IO.Socket? _socket;
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<List<ChatMessage>> _historyController = StreamController<List<ChatMessage>>.broadcast();
  bool _isConnected = false;
  String? _conversationId;
  String? _userId;
  String? _targetUserId;

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<List<ChatMessage>> get historyStream => _historyController.stream;
  bool get isConnected => _isConnected && _socket?.connected == true;

  /// Connect to the chat using Socket.io WebSockets
  Future<void> connect({
    required String userId,
    required String userRole,
    required String targetUserId,
    required String targetUserRole,
  }) async {
    // Disconnect existing connection
    if (_socket != null) {
      await disconnect();
    }

    final sortedIds = [userId, targetUserId]..sort();
    _conversationId = sortedIds.join(':');
    _userId = userId;
    _targetUserId = targetUserId;
    final conversationId = _conversationId!;

    print('Connecting to chat service via Socket.io for conversation: $conversationId');

    try {
      // Get chat service URL from API config
      // Socket.io client uses HTTP/HTTPS URL, not ws://
      final chatBaseUrl = ApiConfig.chatBaseUrl;

      // Use Completer to wait for connection
      final completer = Completer<void>();
      bool connectionEstablished = false;

      // Create Socket.io connection
      _socket = IO.io(
        chatBaseUrl,
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
      );

      // Connection event handlers
      _socket!.onConnect((_) {
        print('✓ Connected to chat service via Socket.io');
        _isConnected = true;
        connectionEstablished = true;
        
        // Join conversation room
        _socket!.emit('join_conversation', {
          'userId': userId,
          'targetUserId': targetUserId,
        });

        // Load chat history
        _loadChatHistory(userId, targetUserId);

        // Complete the future if not already completed
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _socket!.onDisconnect((_) {
        print('✗ Disconnected from chat service');
        _isConnected = false;
      });

      _socket!.onConnectError((error) {
        print('✗ Socket.io connection error: $error');
        _isConnected = false;
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      _socket!.onError((error) {
        print('✗ Socket.io error: $error');
        _isConnected = false;
      });

      // Listen for new messages
      _socket!.on('message_received', (data) {
        try {
          final message = ChatMessage.fromMap(data as Map<String, dynamic>);
          _messageController.add(message);
        } catch (e) {
          print('Error parsing received message: $e');
        }
      });

      // Listen for messages being marked as read
      _socket!.on('messages_read', (data) {
        print('Messages marked as read: $data');
        // Could emit an event to update UI if needed
      });

      // Connect and wait for connection to establish
      _socket!.connect();
      
      // Wait for connection with timeout
      try {
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (!connectionEstablished) {
              throw TimeoutException('Connection timeout after 10 seconds');
            }
          },
        );
      } catch (e) {
        _isConnected = false;
        if (_socket != null) {
          _socket!.disconnect();
          _socket!.dispose();
          _socket = null;
        }
        rethrow;
      }
    } catch (e) {
      _isConnected = false;
      print('✗ Error connecting to chat service: $e');
      rethrow;
    }
  }

  /// Load chat history from REST API
  Future<void> _loadChatHistory(String userId, String targetUserId) async {
    final api = ApiService();
    try {
      print('Loading chat history for userId: $userId, targetUserId: $targetUserId');
      final messages = await api.getChatMessages(
        userId: userId,
        targetUserId: targetUserId,
      );
      print('Received ${messages.length} messages from chat service');
      final chatMessages = messages
          .map((m) => ChatMessage.fromMap(m))
          .toList();
      _historyController.add(chatMessages);
    } catch (e) {
      print('Error loading chat history: $e');
      // Don't rethrow - allow connection to continue even if history fails
    } finally {
      api.close();
    }
  }

  /// Send a message via REST API (Socket.io will broadcast it)
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
      // The Socket.io server will also broadcast it, but we add it here for immediate UI update
      final chatMessage = ChatMessage.fromMap(response);
      _messageController.add(chatMessage);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    } finally {
      api.close();
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String userId, String targetUserId) async {
    // Note: This would require a REST API endpoint for marking messages as read
    // For now, we'll leave this as a placeholder
    print('Mark as read not yet implemented via REST API');
  }

  /// Disconnect from chat
  Future<void> disconnect() async {
    if (_socket != null) {
      if (_conversationId != null && _userId != null && _targetUserId != null) {
        _socket!.emit('leave_conversation', {
          'userId': _userId,
          'targetUserId': _targetUserId,
        });
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _conversationId = null;
    _userId = null;
    _targetUserId = null;
  }

  /// Get messages via REST API (fallback when WebSocket is not available)
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

  // Methods used by AdminChatPage
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
