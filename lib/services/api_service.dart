import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:exam_management_app/config/api_config.dart';
import 'package:exam_management_app/models/index.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  static const List<int> _chatIdPrefix = [0x45, 0x4d, 0x41, 0x50]; // 'EMAP'
  static final RegExp _uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static final RegExp _mongoIdPattern = RegExp(r'^[0-9a-fA-F]{24}$');

  final http.Client _client;
  final String _baseUrl;
  final String _chatBaseUrl;

  ApiService({http.Client? client, String? baseUrl, String? chatBaseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _chatBaseUrl = chatBaseUrl ?? ApiConfig.chatBaseUrl;

  Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Uri _buildChatUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_chatBaseUrl$path').replace(queryParameters: query);
  }

  /// Test chat service health (public method for connection testing)
  Future<bool> testChatServiceHealth() async {
    try {
      final uri = _buildChatUri('/health');
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String _encodeChatUserId(String id) {
    if (id.isEmpty) return id;
    final trimmed = id.trim();
    if (_uuidPattern.hasMatch(trimmed)) {
      return trimmed;
    }
    if (!_mongoIdPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    final bytes = Uint8List(16);
    bytes.setRange(0, _chatIdPrefix.length, _chatIdPrefix);

    for (var i = 0; i < 12; i++) {
      final hexPair = trimmed.substring(i * 2, i * 2 + 2);
      bytes[4 + i] = int.parse(hexPair, radix: 16);
    }

    return Uuid.unparse(bytes);
  }

  String _decodeChatUserId(String id) {
    if (id.isEmpty) return id;
    if (!_uuidPattern.hasMatch(id)) {
      return id;
    }

    try {
      final parsed = Uint8List.fromList(Uuid.parse(id));
      for (var i = 0; i < _chatIdPrefix.length; i++) {
        if (parsed[i] != _chatIdPrefix[i]) {
          return id;
        }
      }

      final buffer = StringBuffer();
      for (var i = _chatIdPrefix.length; i < parsed.length; i++) {
        buffer.write(parsed[i].toRadixString(16).padLeft(2, '0'));
      }
      return buffer.toString();
    } catch (_) {
      return id;
    }
  }

  String _decodeConversationId(String id) {
    if (id.isEmpty) return id;
    final parts = id.split(':');
    if (parts.length != 2) return id;
    final decoded = parts.map(_decodeChatUserId).toList();
    return '${decoded[0]}:${decoded[1]}';
  }

  void _normalizeChatMessageIds(Map<String, dynamic> message) {
    if (message.containsKey('from_user_id')) {
      final decoded = _decodeChatUserId(message['from_user_id'].toString());
      message['from_user_id'] = decoded;
      message['fromUserId'] ??= decoded;
    }
    if (message.containsKey('fromUserId')) {
      final decoded = _decodeChatUserId(message['fromUserId'].toString());
      message['fromUserId'] = decoded;
      message['from_user_id'] ??= decoded;
    }
    if (message.containsKey('to_user_id')) {
      final decoded = _decodeChatUserId(message['to_user_id'].toString());
      message['to_user_id'] = decoded;
      message['toUserId'] ??= decoded;
    }
    if (message.containsKey('toUserId')) {
      final decoded = _decodeChatUserId(message['toUserId'].toString());
      message['toUserId'] = decoded;
      message['to_user_id'] ??= decoded;
    }
    if (message.containsKey('conversation_id')) {
      final decoded = _decodeConversationId(message['conversation_id'].toString());
      message['conversation_id'] = decoded;
      message['conversationId'] ??= decoded;
    }
    if (message.containsKey('conversationId')) {
      final decoded = _decodeConversationId(message['conversationId'].toString());
      message['conversationId'] = decoded;
      message['conversation_id'] ??= decoded;
    }
    if (message.containsKey('studentId')) {
      message['studentId'] = _decodeChatUserId(message['studentId'].toString());
    }
    if (message.containsKey('assignedAdmin')) {
      message['assignedAdmin'] = _decodeChatUserId(message['assignedAdmin'].toString());
    }
    if (message.containsKey('assigned_admin')) {
      message['assigned_admin'] = _decodeChatUserId(message['assigned_admin'].toString());
    }
    if (message.containsKey('participant_1')) {
      message['participant_1'] = _decodeChatUserId(message['participant_1'].toString());
    }
    if (message.containsKey('participant_2')) {
      message['participant_2'] = _decodeChatUserId(message['participant_2'].toString());
    }
    if (message.containsKey('answered_by')) {
      message['answered_by'] = _decodeChatUserId(message['answered_by'].toString());
    }
    if (message.containsKey('answeredBy')) {
      message['answeredBy'] = _decodeChatUserId(message['answeredBy'].toString());
    }
  }

  void _normalizeChatMessages(List<Map<String, dynamic>> messages) {
    for (final message in messages) {
      _normalizeChatMessageIds(message);
      if (message['lastMessage'] is Map<String, dynamic>) {
        _normalizeChatMessageIds(message['lastMessage'] as Map<String, dynamic>);
      }
      if (message['student'] is Map<String, dynamic>) {
        final studentMap = message['student'] as Map<String, dynamic>;
        if (studentMap.containsKey('id')) {
          studentMap['id'] = _decodeChatUserId(studentMap['id'].toString());
        }
      }
    }
  }

  Future<Map<String, dynamic>> getExam(String id) async {
    final uri = _buildUri('/api/exams/$id');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          throw ApiException(
            'GET /api/exams/$id failed: Empty response body',
            response.statusCode,
            '',
          );
        }
        try {
          final decoded = json.decode(body) as Map<String, dynamic>;
          // Backend returns { success: true, data: {...} }
          if (decoded.containsKey('data')) {
            return decoded['data'] as Map<String, dynamic>;
          }
          // Fallback: return the whole response if no 'data' key
          return decoded;
        } catch (e) {
          throw ApiException(
            'GET /api/exams/$id failed: Invalid JSON response',
            response.statusCode,
            body,
          );
        }
      }
      throw ApiException('GET /api/exams/$id failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      // Handle connection errors
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') || 
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Normalizes exam data for JSON encoding
  /// Converts ObjectIds to hex strings and DateTimes to ISO strings
  Map<String, dynamic> _normalizeExamData(Map<String, dynamic> exam) {
    final normalized = <String, dynamic>{};
    
    for (final entry in exam.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        normalized[key] = value.toHexString();
      } else if (value is DateTime) {
        normalized[key] = value.toIso8601String();
      } else if (value is List) {
        // Handle lists of ObjectIds
        normalized[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          }
          return item;
        }).toList();
      } else {
        normalized[key] = value;
      }
    }
    
    return normalized;
  }

  Future<String> createExam(dynamic exam) async {
    final uri = _buildUri('/api/exams');
    
    // Handle Exam object
    Map<String, dynamic> examData;
    if (exam is Exam) {
      examData = exam.toJson();
    } else if (exam is Map<String, dynamic>) {
      examData = _normalizeExamData(exam);
    } else {
      throw ArgumentError('createExam expects Exam object or Map<String, dynamic>');
    }
    
    // Ensure required fields are present and valid
    // Handle duration - convert to int if needed
    if (examData['duration'] == null) {
      examData['duration'] = 60; // Default duration
    } else if (examData['duration'] is String) {
      final parsed = int.tryParse(examData['duration'] as String);
      if (parsed == null || parsed < 1) {
        throw ArgumentError('duration must be a positive integer');
      }
      examData['duration'] = parsed;
    } else if (examData['duration'] is double) {
      final parsed = (examData['duration'] as double).toInt();
      if (parsed < 1) {
        throw ArgumentError('duration must be a positive integer');
      }
      examData['duration'] = parsed;
    } else if (examData['duration'] is! int || (examData['duration'] as int) < 1) {
      throw ArgumentError('duration must be a positive integer');
    }
    
    // Ensure createdBy is a valid ObjectId string
    if (examData['createdBy'] == null) {
      throw ArgumentError('createdBy is required and must be a valid MongoDB ObjectId string');
    }
    if (examData['createdBy'] is! String) {
      throw ArgumentError('createdBy must be a valid MongoDB ObjectId string');
    }
    // Validate ObjectId format (24 hex characters)
    final createdByStr = examData['createdBy'] as String;
    if (createdByStr.length != 24 || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(createdByStr)) {
      throw ArgumentError('createdBy must be a valid MongoDB ObjectId string (24 hex characters)');
    }
    
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode(examData),
      );
      if (response.statusCode == 201) {
        final body = response.body.trim();
        if (body.isEmpty) {
          throw ApiException(
            'POST /api/exams failed: Empty response body',
            response.statusCode,
            '',
          );
        }
        try {
          final decoded = json.decode(body) as Map<String, dynamic>;
          // Backend returns { success: true, data: {...}, insertedId: "..." }
          if (decoded.containsKey('insertedId')) {
            return decoded['insertedId'] as String;
          } else if (decoded.containsKey('data') && decoded['data'] is Map) {
            // Try to get insertedId from data object
            final data = decoded['data'] as Map<String, dynamic>;
            if (data.containsKey('_id')) {
              return data['_id'].toString();
            }
          }
          throw ApiException(
            'POST /api/exams failed: Response missing insertedId',
            response.statusCode,
            body,
          );
        } catch (e) {
          if (e is ApiException) {
            rethrow;
          }
          throw ApiException(
            'POST /api/exams failed: Invalid JSON response',
            response.statusCode,
            body,
          );
        }
      }
      throw ApiException('POST /api/exams failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      // Handle connection errors
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') || 
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get chat messages between two users
  Future<List<Map<String, dynamic>>> getChatMessages({
    required String userId,
    required String targetUserId,
  }) async {
    final encodedUserId = _encodeChatUserId(userId);
    final encodedTargetUserId = _encodeChatUserId(targetUserId);
    final uri = _buildChatUri('/api/chat/conversation', {
      'userId': encodedUserId,
      'targetUserId': encodedTargetUserId,
    });
    
    print('GET $uri');
    print('  Original userId: $userId -> Encoded: $encodedUserId');
    print('  Original targetUserId: $targetUserId -> Encoded: $encodedTargetUserId');
    
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }
        try {
          final decoded = json.decode(body) as Map<String, dynamic>;
          if (decoded.containsKey('success') && decoded['success'] == true) {
            final data = decoded['data'];
            if (data is List) {
              final messages = data.cast<Map<String, dynamic>>();
              _normalizeChatMessages(messages);
              return messages;
            }
          }
          // If success is false, log the error
          if (decoded.containsKey('success') && decoded['success'] == false) {
            final error = decoded['error'] ?? decoded['errors'] ?? 'Unknown error';
            print('  Server error: $error');
            throw ApiException(
              'GET /api/chat/conversation failed: $error',
              response.statusCode,
              body,
            );
          }
          return [];
        } catch (e) {
          if (e is ApiException) rethrow;
          throw ApiException(
            'GET /api/chat/conversation failed: Invalid JSON response',
            response.statusCode,
            body,
          );
        }
      }
      
      // Try to parse error response
      String errorMessage = 'Unknown error';
      try {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        errorMessage = decoded['error'] ?? decoded['message'] ?? errorMessage;
      } catch (_) {
        errorMessage = response.body;
      }
      
      print('  Error response: $errorMessage');
      throw ApiException(
        'GET /api/chat/conversation failed: $errorMessage',
        response.statusCode,
        response.body,
      );
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get all chat conversations summary (students with history, unread counts)
  Future<List<Map<String, dynamic>>> getChatConversations() async {
    final uri = _buildChatUri('/api/chat/conversations');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          final conversations = (decoded['data'] as List).cast<Map<String, dynamic>>();
          _normalizeChatMessages(conversations);
          return conversations;
        }
        return [];
      }
      throw ApiException('GET /api/chat/conversations failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get unread messages (from students)
  Future<List<Map<String, dynamic>>> getUnreadChatMessages() async {
    final uri = _buildChatUri('/api/chat/unread');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          final messages = (decoded['data'] as List).cast<Map<String, dynamic>>();
          _normalizeChatMessages(messages);
          return messages;
        }
        return [];
      }
      throw ApiException('GET /api/chat/unread failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get unread message count for a specific user (student or teacher)
  Future<int> getUnreadChatCount({
    required String userId,
    required String userRole,
  }) async {
    final encodedUserId = _encodeChatUserId(userId);
    final uri = _buildChatUri('/api/chat/unread/count', {
      'userId': encodedUserId,
      'userRole': userRole,
    });
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return 0;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['count'] != null) {
          return (decoded['count'] as num).toInt();
        }
        return 0;
      }
      throw ApiException('GET /api/chat/unread/count failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        // Return 0 if service is unavailable (don't show error for count)
        return 0;
      }
      rethrow;
    }
  }

  /// Send a student message
  Future<Map<String, dynamic>> sendStudentMessage({
    required String fromUserId,
    required String toUserId,
    required String message,
    String? toUserRole,
  }) async {
    final uri = _buildChatUri('/api/chat/student');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'fromUserId': _encodeChatUserId(fromUserId),
          'toUserId': _encodeChatUserId(toUserId),
          'message': message,
          if (toUserRole != null) 'toUserRole': toUserRole,
        }),
      );
      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          _normalizeChatMessageIds(data);
          return data;
        }
        throw ApiException('POST /api/chat/student failed: Invalid response', response.statusCode, response.body);
      }
      throw ApiException('POST /api/chat/student failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Send a teacher message
  Future<Map<String, dynamic>> sendTeacherMessage({
    required String fromUserId,
    required String toUserId,
    required String message,
    String? toUserRole,
  }) async {
    final uri = _buildChatUri('/api/chat/teacher');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'fromUserId': _encodeChatUserId(fromUserId),
          'toUserId': _encodeChatUserId(toUserId),
          'message': message,
          if (toUserRole != null) 'toUserRole': toUserRole,
        }),
      );
      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          _normalizeChatMessageIds(data);
          return data;
        }
        throw ApiException('POST /api/chat/teacher failed: Invalid response', response.statusCode, response.body);
      }
      throw ApiException('POST /api/chat/teacher failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Send an admin message
  Future<Map<String, dynamic>> sendAdminMessage({
    required String fromUserId,
    required String toUserId,
    required String message,
    String? toUserRole,
  }) async {
    final uri = _buildChatUri('/api/chat/admin');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'fromUserId': _encodeChatUserId(fromUserId),
          'toUserId': _encodeChatUserId(toUserId),
          'message': message,
          if (toUserRole != null) 'toUserRole': toUserRole,
        }),
      );
      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          _normalizeChatMessageIds(data);
          return data;
        }
        throw ApiException('POST /api/chat/admin failed: Invalid response', response.statusCode, response.body);
      }
      throw ApiException('POST /api/chat/admin failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get default admin id for helpdesk
  Future<String?> getDefaultAdminId() async {
    final uri = _buildChatUri('/api/chat/default-admin');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['adminId'] is String) {
          return _decodeChatUserId(decoded['adminId'] as String);
        }
        return null;
      }
      if (response.statusCode == 404) return null;
      throw ApiException('GET /api/chat/default-admin failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get conversation metadata
  Future<Map<String, dynamic>?> getConversationMetadata({
    required String userId,
    required String targetUserId,
  }) async {
    final encodedUser = _encodeChatUserId(userId);
    final encodedTarget = _encodeChatUserId(targetUserId);
    final uri = _buildChatUri('/api/chat/conversation/$encodedUser/$encodedTarget/metadata');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          if (data.containsKey('userId')) {
            data['userId'] = _decodeChatUserId(data['userId'].toString());
          }
          if (data.containsKey('targetUserId')) {
            data['targetUserId'] = _decodeChatUserId(data['targetUserId'].toString());
          }
          if (data.containsKey('assignedAdmin')) {
            data['assignedAdmin'] = _decodeChatUserId(data['assignedAdmin'].toString());
          }
          if (data.containsKey('assigned_admin')) {
            data['assigned_admin'] = _decodeChatUserId(data['assigned_admin'].toString());
          }
          return data;
        }
        return null;
      }
      throw ApiException('GET /api/chat/conversation/metadata failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Create or update conversation metadata
  Future<Map<String, dynamic>?> createOrUpdateConversation({
    required String userId,
    required String targetUserId,
    String? topic,
    String? priority,
    String? assignedAdmin,
  }) async {
    final uri = _buildChatUri('/api/chat/conversation');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'userId': _encodeChatUserId(userId),
          'targetUserId': _encodeChatUserId(targetUserId),
          if (topic != null) 'topic': topic,
          if (priority != null) 'priority': priority,
          if (assignedAdmin != null)
            'assignedAdmin': _encodeChatUserId(assignedAdmin),
        }),
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          if (data.containsKey('userId')) {
            data['userId'] = _decodeChatUserId(data['userId'].toString());
          }
          if (data.containsKey('targetUserId')) {
            data['targetUserId'] = _decodeChatUserId(data['targetUserId'].toString());
          }
          return data;
        }
        return null;
      }
      throw ApiException('POST /api/chat/conversation failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      rethrow;
    }
  }

  /// Mark messages as read for a student
  Future<bool> markChatMessagesAsRead(String studentId) async {
    final encodedStudentId = _encodeChatUserId(studentId);
    final uri = _buildChatUri('/api/chat/read/$encodedStudentId');
    try {
      final response = await _client.put(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return false;
        final decoded = json.decode(body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('PUT /api/chat/read/:studentId failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Close conversation and delete its messages
  Future<bool> closeConversation({
    required String userId,
    required String targetUserId,
    String? topic,
    String? priority,
    String? assignedAdmin,
  }) async {
    final queryParams = <String, String>{};
    if (topic != null) queryParams['topic'] = topic;
    if (priority != null) queryParams['priority'] = priority;
    if (assignedAdmin != null) {
      queryParams['assignedAdmin'] = _encodeChatUserId(assignedAdmin);
    }
    
    final encodedUser = _encodeChatUserId(userId);
    final encodedTarget = _encodeChatUserId(targetUserId);
    final uri = _buildChatUri('/api/chat/conversation/$encodedUser/$encodedTarget', queryParams);
    try {
      final response = await _client.delete(
        uri,
        headers: {
          'accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return true;
        final decoded = json.decode(body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('DELETE /api/chat/conversation failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Chat service is not running. Please start the chat service at $_chatBaseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Authenticate user
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final uri = _buildUri('/api/auth/login');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['user'] != null) {
          return decoded['user'] as Map<String, dynamic>;
        }
        return null;
      }

      if (response.statusCode == 401) {
        return null;
      }

      throw ApiException('POST /api/auth/login failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get current user details
  Future<Map<String, dynamic>?> getCurrentUser(String userId) async {
    final uri = _buildUri('/api/auth/user/$userId');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['user'] != null) {
          return decoded['user'] as Map<String, dynamic>;
        }
        return null;
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw ApiException('GET /api/auth/user failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Change user password
  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = _buildUri('/api/auth/password');
    try {
      final response = await _client.put(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }

      if (response.statusCode == 400 || response.statusCode == 404) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        throw ApiException(
          decoded['error']?.toString() ?? 'Failed to change password',
          response.statusCode,
          response.body,
        );
      }

      throw ApiException('PUT /api/auth/password failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getPaginatedData(Uri uri, {
    required String operation,
    bool isChat = false,
  }) async {
    final headers = {
      'accept': 'application/json',
    };
    try {
      final response = await _client.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      }
      throw ApiException('$operation failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      final isConnError = errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable');
      if (isConnError) {
        throw ApiException(
          isChat
              ? 'Chat service is not running. Please start the chat service at $_chatBaseUrl'
              : 'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get exams created by a teacher
  Future<List<Map<String, dynamic>>> getTeacherExams({
    required String teacherId,
    int page = 0,
    int limit = 20,
  }) async {
    final uri = _buildUri('/api/exams/teacher/$teacherId', {
      'page': '$page',
      'limit': '$limit',
    });
    return _getPaginatedData(uri, operation: 'GET /api/exams/teacher');
  }

  /// Get exams assigned to a student
  Future<List<Map<String, dynamic>>> getStudentExams({
    required String studentId,
    int page = 0,
    int limit = 20,
  }) async {
    final uri = _buildUri('/api/exams/student/$studentId', {
      'page': '$page',
      'limit': '$limit',
    });
    return _getPaginatedData(uri, operation: 'GET /api/exams/student');
  }

  /// Get all exams (optionally filter by teacher)
  Future<List<Map<String, dynamic>>> getExams({
    int page = 0,
    int limit = 20,
    String? teacherId,
  }) async {
    final query = {
      'page': '$page',
      'limit': '$limit',
      if (teacherId != null) 'teacherId': teacherId,
    };
    final uri = _buildUri('/api/exams', query);
    return _getPaginatedData(uri, operation: 'GET /api/exams');
  }

  /// Update exam fields
  Future<bool> updateExam(String examId, Map<String, dynamic> updates) async {
    final uri = _buildUri('/api/exams/$examId');
    try {
      final response = await _client.put(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('PUT /api/exams failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Delete exam
  Future<bool> deleteExam(String examId) async {
    final uri = _buildUri('/api/exams/$examId');
    try {
      final response = await _client.delete(
        uri,
        headers: {
          'accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('DELETE /api/exams failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Update exam status
  Future<bool> updateExamStatus(String examId, String status, {DateTime? newDate}) async {
    final uri = _buildUri('/api/exams/$examId/status');
    try {
      final bodyData = <String, dynamic>{'status': status};
      if (newDate != null) {
        bodyData['newDate'] = newDate.toIso8601String();
      }
      final response = await _client.patch(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode(bodyData),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('PATCH /api/exams/status failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Assign student to an exam
  Future<bool> assignStudentToExam(String examId, String studentId) async {
    final uri = _buildUri('/api/exams/$examId/assign/$studentId');
    try {
      final response = await _client.post(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('POST /api/exams/assign failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Remove student assignment from exam
  Future<bool> unassignStudentFromExam(String examId, String studentId) async {
    final uri = _buildUri('/api/exams/$examId/assign/$studentId');
    try {
      final response = await _client.delete(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('DELETE /api/exams/assign failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get students assigned to an exam
  Future<List<Map<String, dynamic>>> getStudentsAssignedToExam(String examId) async {
    final uri = _buildUri('/api/exams/$examId/students');
    return _getPaginatedData(uri, operation: 'GET /api/exams/students');
  }

  /// Create a new student
  Future<Map<String, dynamic>?> createStudent({
    required String fullName,
    required String email,
    required String studentId,
    String? className,
    String? phoneNumber,
    String? address,
  }) async {
    final uri = _buildUri('/api/students');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'fullName': fullName,
          'email': email,
          'studentId': studentId,
          'rollNumber': studentId, // Also set rollNumber to match studentId
          'className': className,
          'phoneNumber': phoneNumber,
          'address': address,
          'assignedExams': [],
        }),
      );
      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return null;
      }
      throw ApiException('POST /api/students failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Fetch teachers list
  Future<List<Map<String, dynamic>>> getTeachers({
    int page = 0,
    int limit = 100,
  }) async {
    final uri = _buildUri('/api/teachers', {
      'page': '$page',
      'limit': '$limit',
    });
    return _getPaginatedData(uri, operation: 'GET /api/teachers');
  }

  /// Fetch teacher by ID
  Future<Map<String, dynamic>?> getTeacher(String teacherId) async {
    final uri = _buildUri('/api/teachers/$teacherId');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return null;
      }
      if (response.statusCode == 404) {
        return null;
      }
      throw ApiException('GET /api/teachers/:id failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Fetch students list
  Future<List<Map<String, dynamic>>> getStudents({
    int page = 0,
    int limit = 100,
  }) async {
    final uri = _buildUri('/api/students', {
      'page': '$page',
      'limit': '$limit',
    });
    return _getPaginatedData(uri, operation: 'GET /api/students');
  }

  /// Fetch student by ID
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    final uri = _buildUri('/api/students/$studentId');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return null;
      }
      if (response.statusCode == 404) {
        return null;
      }
      throw ApiException('GET /api/students/:id failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Fetch questions
  Future<List<Map<String, dynamic>>> getQuestions({
    int page = 0,
    int limit = 100,
  }) async {
    final uri = _buildUri('/api/questions', {
      'page': '$page',
      'limit': '$limit',
    });
    return _getPaginatedData(uri, operation: 'GET /api/questions');
  }

  /// Fetch question by ID
  Future<Map<String, dynamic>?> getQuestion(String questionId) async {
    final uri = _buildUri('/api/questions/$questionId');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return null;
      }
      if (response.statusCode == 404) {
        return null;
      }
      throw ApiException('GET /api/questions/:id failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Fetch questions by IDs
  Future<List<Map<String, dynamic>>> getQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final uri = _buildUri('/api/questions/ids', {
      'ids': ids.join(','),
    });
    return _getPaginatedData(uri, operation: 'GET /api/questions/ids');
  }

  /// Create a new question
  Future<String> createQuestion(Map<String, dynamic> questionData) async {
    final uri = _buildUri('/api/questions');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode(questionData),
      );
      if (response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['insertedId'] != null) {
          return decoded['insertedId'].toString();
        }
        if (decoded['data'] != null && decoded['data']['_id'] != null) {
          return decoded['data']['_id'].toString();
        }
        throw ApiException('POST /api/questions failed: missing insertedId', response.statusCode, response.body);
      }
      throw ApiException('POST /api/questions failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Update existing question
  Future<bool> updateQuestion(String questionId, Map<String, dynamic> updates) async {
    final uri = _buildUri('/api/questions/$questionId');
    try {
      final response = await _client.put(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      throw ApiException('PUT /api/questions failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Delete question
  Future<bool> deleteQuestion(String questionId) async {
    final uri = _buildUri('/api/questions/$questionId');
    try {
      final response = await _client.delete(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
      if (response.statusCode == 404) {
        return false;
      }
      throw ApiException('DELETE /api/questions failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Submit exam answers and receive result
  Future<Map<String, dynamic>> submitExamAnswers({
    required String examId,
    required String studentId,
    required Map<String, dynamic> answers,
    required List<Map<String, dynamic>> questions,
    bool isTimeUp = false,
  }) async {
    final uri = _buildUri('/api/exam-results/submit');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'examId': examId,
          'studentId': studentId,
          'answers': answers,
          'questions': questions,
          'isTimeUp': isTimeUp,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          return decoded;
        }
        throw ApiException('POST /api/exam-results/submit failed: invalid response', response.statusCode, response.body);
      }
      throw ApiException('POST /api/exam-results/submit failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      final errorMsg = e.toString();
      if (errorMsg.contains('Connection refused') ||
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable')) {
        throw ApiException(
          'Main API service is not running. Please start the main API at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  void close() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String body;

  ApiException(this.message, this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $message -> $body';
}

