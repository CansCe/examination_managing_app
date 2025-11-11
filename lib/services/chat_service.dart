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
  bool get isConnected {
    // Check both the flag and the actual socket connection state
    final socketConnected = _socket?.connected ?? false;
    final result = _isConnected && socketConnected;
    if (_isConnected && !socketConnected) {
      // Socket was connected but is now disconnected - update flag
      _isConnected = false;
    }
    return result;
  }

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

      // Create Socket.io connection with automatic reconnection
      _socket = IO.io(
        chatBaseUrl,
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection() // Enable automatic reconnection
          .setReconnectionAttempts(5) // Try to reconnect up to 5 times
          .setReconnectionDelay(1000) // Wait 1 second between reconnection attempts
          .setReconnectionDelayMax(5000) // Max 5 seconds between attempts
          .build(),
      );

      // Connection event handlers
      _socket!.onConnect((_) {
        print('Connected to chat service via Socket.io (socket ID: ${_socket!.id})');
        _isConnected = true;
        connectionEstablished = true;
        
        // Verify socket is actually connected
        if (_socket!.connected) {
          print('Socket connection verified: connected = ${_socket!.connected}');
        } else {
          print('Warning: Socket onConnect fired but socket.connected is false');
        }
        
        // Join conversation room for real-time message delivery
        print('Joining conversation room for real-time updates');
        _socket!.emit('join_conversation', {
          'userId': userId,
          'targetUserId': targetUserId,
        });
        print('Join request sent - waiting for confirmation');

        // Load chat history (existing messages)
        _loadChatHistory(userId, targetUserId);

        // Complete the future if not already completed
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _socket!.onDisconnect((reason) {
        // Only log if it's an unexpected disconnect (not a manual disconnect)
        if (_isConnected) {
          print('Disconnected from chat service: $reason');
          print('Automatic reconnection will be attempted...');
        } else {
          print('Disconnected from chat service (expected)');
        }
        _isConnected = false;
      });
      
      // Handle reconnection
      _socket!.onReconnect((attemptNumber) {
        print('Reconnected to chat service after $attemptNumber attempt(s)');
        _isConnected = true;
        
        // Re-join conversation room after reconnection
        if (_userId != null && _targetUserId != null) {
          print('Re-joining conversation room after reconnection');
          _socket!.emit('join_conversation', {
            'userId': _userId,
            'targetUserId': _targetUserId,
          });
          
          // Reload chat history after reconnection to get any missed messages
          _loadChatHistory(_userId!, _targetUserId!);
        }
      });
      
      // Handle reconnection attempts
      _socket!.onReconnectAttempt((attemptNumber) {
        print('Reconnection attempt $attemptNumber...');
      });
      
      // Handle reconnection errors
      _socket!.onReconnectError((error) {
        print('Reconnection error: $error');
      });

      _socket!.onConnectError((error) {
        print('Socket.io connection error: $error');
        _isConnected = false;
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      _socket!.onError((error) {
        print('Socket.io error: $error');
        _isConnected = false;
      });

      // Listen for new messages - REAL-TIME LIVE FEED
      _socket!.on('message_received', (data) {
        try {
          print('REAL-TIME: Received message via Socket.io');
          final message = ChatMessage.fromMap(data as Map<String, dynamic>);
          print('   From: ${message.fromUserRole} ${message.fromUserId}');
          print('   To: ${message.toUserRole} ${message.toUserId}');
          print('   Message: ${message.message.substring(0, 50)}${message.message.length > 50 ? '...' : ''}');
          
          // Immediately add to stream for real-time display
          _messageController.add(message);
          print('   Message added to stream - UI should update immediately');
        } catch (e) {
          print('Error parsing received message: $e');
          print('   Raw data: $data');
        }
      });

      // Listen for messages being marked as read
      _socket!.on('messages_read', (data) {
        print('Messages marked as read: $data');
        // Could emit an event to update UI if needed
      });
      
      // Listen for join confirmation
      _socket!.on('joined_conversation', (data) {
        print('Joined conversation room: ${data['conversationId']}');
        print('Ready to receive real-time messages');
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
        
        // Double-check connection state after waiting
        if (_socket != null && _socket!.connected) {
          print('Connection fully established and verified');
          _isConnected = true;
        } else {
          print('Warning: Connection completed but socket is not connected');
          _isConnected = false;
          throw Exception('Socket connection not fully established');
        }
      } catch (e) {
        _isConnected = false;
        print('Connection failed: $e');
        if (_socket != null) {
          _socket!.disconnect();
          _socket!.dispose();
          _socket = null;
        }
        rethrow;
      }
    } catch (e) {
      _isConnected = false;
      print('Error connecting to chat service: $e');
      rethrow;
    }
  }

  /// Load chat history from REST API
  Future<void> _loadChatHistory(String userId, String targetUserId) async {
    final api = ApiService();
    try {
      print('Loading chat history for userId: $userId, targetUserId: $targetUserId');
      print('  userId format: ${userId.contains('-') ? 'UUID' : 'ObjectId'}');
      print('  targetUserId format: ${targetUserId.contains('-') ? 'UUID' : 'ObjectId'}');
      
      final messages = await api.getChatMessages(
        userId: userId,
        targetUserId: targetUserId,
      );
      
      print('Received ${messages.length} messages from chat service');
      if (messages.isNotEmpty) {
        print('  First message: ${messages.first['message']} from ${messages.first['from_user_role']}');
        print('  Last message: ${messages.last['message']} from ${messages.last['from_user_role']}');
      }
      
      final chatMessages = messages
          .map((m) => ChatMessage.fromMap(m))
          .toList();
      
      print('Converted to ${chatMessages.length} ChatMessage objects');
      _historyController.add(chatMessages);
    } catch (e) {
      print('Error loading chat history: $e');
      print('  Stack trace: ${StackTrace.current}');
      // Don't rethrow - allow connection to continue even if history fails
      // But add empty list to indicate history was attempted
      _historyController.add([]);
    } finally {
      api.close();
    }
  }
  
  /// Manually reload chat history (public method for refresh)
  Future<void> reloadHistory() async {
    if (_userId != null && _targetUserId != null) {
      await _loadChatHistory(_userId!, _targetUserId!);
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

      print('Message sent to server - Socket.io will broadcast to all receivers in real-time');
      
      // Don't add message here - the Socket.io server will broadcast it via message_received event
      // This prevents duplicate messages (one from REST API response, one from Socket.io broadcast)
      // The message will appear immediately when the Socket.io broadcast is received by all clients
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    } finally {
      api.close();
    }
  }

  /// Mark messages as read for a student
  /// This marks all unread messages from the targetUserId (student) as read
  Future<void> markAsRead(String userId, String targetUserId) async {
    try {
      print('Marking messages as read for student: $targetUserId');
      final api = ApiService();
      final success = await api.markChatMessagesAsRead(targetUserId);
      api.close();
      
      if (success) {
        print('Messages marked as read successfully');
        // Optionally emit a Socket.io event to notify other clients
        // The backend already handles this via Socket.io in markAsRead controller
      } else {
        print('Failed to mark messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      // Don't rethrow - this is not critical for the chat to function
    }
  }

  /// Disconnect from chat
  Future<void> disconnect() async {
    if (_socket != null) {
      // Mark as disconnecting to prevent error logs
      _isConnected = false;
      
      if (_conversationId != null && _userId != null && _targetUserId != null) {
        try {
          _socket!.emit('leave_conversation', {
            'userId': _userId,
            'targetUserId': _targetUserId,
          });
        } catch (e) {
          print('Error emitting leave_conversation: $e');
        }
      }
      
      try {
        _socket!.disconnect();
      } catch (e) {
        print('Error disconnecting socket: $e');
      }
      
      try {
        _socket!.dispose();
      } catch (e) {
        print('Error disposing socket: $e');
      }
      
      _socket = null;
    }
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
