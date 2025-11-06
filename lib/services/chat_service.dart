import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import 'api_service.dart';

class ChatMessage {
  final ObjectId id;
  final String fromUserId;
  final String fromUserRole; // 'student', 'teacher', or 'admin'
  final String toUserId;
  final String toUserRole;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.fromUserRole,
    required this.toUserId,
    required this.toUserRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    ObjectId messageId;
    if (map['_id'] is String) {
      messageId = ObjectId.fromHexString(map['_id']);
    } else if (map['_id'] is ObjectId) {
      messageId = map['_id'];
    } else if (map['_id'] != null) {
      // Handle ObjectId-like objects from MongoDB
      try {
        messageId = ObjectId.fromHexString(map['_id'].toString());
      } catch (e) {
        messageId = ObjectId();
      }
    } else {
      messageId = ObjectId();
    }

    // Helper to convert ObjectId to string
    String convertToString(dynamic value) {
      if (value is String) return value;
      if (value is ObjectId) return value.toHexString();
      if (value != null) {
        try {
          return ObjectId.fromHexString(value.toString()).toHexString();
        } catch (e) {
          return value.toString();
        }
      }
      return '';
    }

    return ChatMessage(
      id: messageId,
      fromUserId: convertToString(map['fromUserId']),
      fromUserRole: map['fromUserRole'] ?? 'student',
      toUserId: convertToString(map['toUserId']),
      toUserRole: map['toUserRole'] ?? 'student',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] is DateTime 
          ? map['timestamp'] 
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id.toHexString(),
      'fromUserId': fromUserId,
      'fromUserRole': fromUserRole,
      'toUserId': toUserId,
      'toUserRole': toUserRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  // Backward-compatibility getters used by older UI code
  String get studentId => fromUserRole == 'student' ? fromUserId : toUserId;
  String get sender => fromUserRole;
}

class ChatSocketService {
  IO.Socket? _socket;
  final String _socketUrl;
  bool _isConnected = false;
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<List<ChatMessage>> _historyController = StreamController<List<ChatMessage>>.broadcast();

  ChatSocketService({String? socketUrl}) 
      : _socketUrl = socketUrl ?? ApiConfig.baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://').replaceFirst('localhost', 'localhost:3000');

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<List<ChatMessage>> get historyStream => _historyController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the chat server
  void connect({
    required String userId,
    required String userRole,
    required String targetUserId,
    required String targetUserRole,
  }) {
    if (_socket != null && _isConnected) {
      disconnect();
    }

    _socket = IO.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.on('connect', (_) {
      _isConnected = true;
      print('✓ Connected to chat server');
      
      // Join chat room
      _socket!.emit('join_chat', {
        'userId': userId,
        'userRole': userRole,
        'targetUserId': targetUserId,
        'targetUserRole': targetUserRole,
      });
    });

    _socket!.on('disconnect', (_) {
      _isConnected = false;
      print('✗ Disconnected from chat server');
    });

    _socket!.on('new_message', (data) {
      try {
        final messageData = data['message'] as Map<String, dynamic>;
        final message = ChatMessage.fromMap(messageData);
        _messageController.add(message);
      } catch (e) {
        print('Error parsing new message: $e');
      }
    });

    _socket!.on('chat_history', (data) {
      try {
        final messages = (data['messages'] as List)
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList();
        _historyController.add(messages);
      } catch (e) {
        print('Error parsing chat history: $e');
      }
    });

    _socket!.on('error', (data) {
      print('Socket error: $data');
    });

    _socket!.on('messages_read', (_) {
      // Handle read receipt if needed
    });
  }

  /// Send a message
  void sendMessage({
    required String message,
    required String fromUserId,
    required String fromUserRole,
    required String toUserId,
    required String toUserRole,
  }) {
    if (!_isConnected || _socket == null) {
      throw Exception('Not connected to chat server');
    }

    _socket!.emit('send_message', {
      'message': message,
      'fromUserId': fromUserId,
      'fromUserRole': fromUserRole,
      'toUserId': toUserId,
      'toUserRole': toUserRole,
    });
  }

  /// Mark messages as read
  void markAsRead(String userId, String targetUserId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('mark_read', {
      'userId': userId,
      'targetUserId': targetUserId,
    });
  }

  /// Disconnect from the server
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
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
    // This method signature is deprecated - use getMessages with both userId and targetUserId
    throw UnimplementedError('Use ChatService.getMessages(userId, targetUserId) instead');
  }

  // These methods should be migrated to use ChatSocketService
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
      // Each item contains studentId
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
