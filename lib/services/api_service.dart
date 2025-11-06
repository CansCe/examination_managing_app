import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:exam_management_app/config/api_config.dart';
import 'package:exam_management_app/models/index.dart';

class ApiService {
  final http.Client _client;
  final String _baseUrl;

  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
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
    final uri = _buildUri('/api/chat/conversation', {
      'userId': userId,
      'targetUserId': targetUserId,
    });
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
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
              return data.cast<Map<String, dynamic>>();
            }
          }
          return [];
        } catch (e) {
          throw ApiException(
            'GET /api/chat/conversation failed: Invalid JSON response',
            response.statusCode,
            body,
          );
        }
      }
      throw ApiException(
        'GET /api/chat/conversation failed',
        response.statusCode,
        response.body,
      );
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get all chat conversations summary (students with history, unread counts)
  Future<List<Map<String, dynamic>>> getChatConversations() async {
    final uri = _buildUri('/api/chat/conversations');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List).cast<Map<String, dynamic>>();
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get unread messages (from students)
  Future<List<Map<String, dynamic>>> getUnreadChatMessages() async {
    final uri = _buildUri('/api/chat/unread');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List).cast<Map<String, dynamic>>();
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
          0,
          errorMsg,
        );
      }
      rethrow;
    }
  }

  /// Get default admin id for helpdesk
  Future<String?> getDefaultAdminId() async {
    final uri = _buildUri('/api/chat/default-admin');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['adminId'] is String) {
          return decoded['adminId'] as String;
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
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
    final uri = _buildUri('/api/chat/conversation/$userId/$targetUserId/metadata');
    try {
      final response = await _client.get(uri, headers: {
        'accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
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
    final uri = _buildUri('/api/chat/conversation');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'targetUserId': targetUserId,
          if (topic != null) 'topic': topic,
          if (priority != null) 'priority': priority,
          if (assignedAdmin != null) 'assignedAdmin': assignedAdmin,
        }),
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return null;
      }
      throw ApiException('POST /api/chat/conversation failed', response.statusCode, response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
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
    if (assignedAdmin != null) queryParams['assignedAdmin'] = assignedAdmin;
    
    final uri = _buildUri('/api/chat/conversation/$userId/$targetUserId', queryParams);
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
          'Backend server is not running. Please start the backend server at $_baseUrl',
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

