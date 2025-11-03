import 'package:mongo_dart/mongo_dart.dart';
import '../config/database_config.dart';
import 'mongodb_service.dart';

class ChatMessage {
  final ObjectId id;
  final String studentId;
  final String? adminId;
  final String message;
  final String sender; // 'student' or 'admin'
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.studentId,
    this.adminId,
    required this.message,
    required this.sender,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'studentId': studentId,
      'adminId': adminId,
      'message': message,
      'sender': sender,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['_id'] is ObjectId ? map['_id'] : ObjectId.fromHexString(map['_id']),
      studentId: map['studentId'] ?? '',
      adminId: map['adminId'] as String?,
      message: map['message'] ?? '',
      sender: map['sender'] ?? 'student',
      timestamp: map['timestamp'] is DateTime 
          ? map['timestamp'] 
          : DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
    );
  }
}

class ChatService {
  // Send a message from student to admin
  static Future<void> sendStudentMessage({
    required String studentId,
    required String message,
  }) async {
    try {
      final db = await MongoDBService.getDatabase();
      final chatMessage = {
        '_id': ObjectId(),
        'studentId': studentId,
        'adminId': null,
        'message': message,
        'sender': 'student',
        'timestamp': DateTime.now(),
        'isRead': false,
      };
      
      await db.collection(DatabaseConfig.chatMessagesCollection).insert(chatMessage);
    } catch (e) {
      print('Error sending student message: $e');
      rethrow;
    }
  }

  // Send a message from admin to student
  static Future<void> sendAdminMessage({
    required String studentId,
    required String adminId,
    required String message,
  }) async {
    try {
      final db = await MongoDBService.getDatabase();
      final chatMessage = {
        '_id': ObjectId(),
        'studentId': studentId,
        'adminId': adminId,
        'message': message,
        'sender': 'admin',
        'timestamp': DateTime.now(),
        'isRead': false,
      };
      
      await db.collection(DatabaseConfig.chatMessagesCollection).insert(chatMessage);
    } catch (e) {
      print('Error sending admin message: $e');
      rethrow;
    }
  }

  // Get all messages for a student
  static Future<List<ChatMessage>> getStudentMessages(String studentId) async {
    try {
      final db = await MongoDBService.getDatabase();
      final messages = await db.collection(DatabaseConfig.chatMessagesCollection)
          .find({'studentId': studentId})
          .toList();
      
      // Sort by timestamp ascending
      messages.sort((a, b) {
        final aTime = a['timestamp'] as DateTime;
        final bTime = b['timestamp'] as DateTime;
        return aTime.compareTo(bTime);
      });
      
      return messages.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      print('Error getting student messages: $e');
      return [];
    }
  }

  // Get all unread messages for admins
  static Future<List<ChatMessage>> getUnreadMessages() async {
    try {
      final db = await MongoDBService.getDatabase();
      final messages = await db.collection(DatabaseConfig.chatMessagesCollection)
          .find({'sender': 'student', 'isRead': false})
          .toList();
      
      // Sort by timestamp descending (newest first)
      messages.sort((a, b) {
        final aTime = a['timestamp'] as DateTime;
        final bTime = b['timestamp'] as DateTime;
        return bTime.compareTo(aTime);
      });
      
      return messages.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      print('Error getting unread messages: $e');
      return [];
    }
  }

  // Get all messages between a student and admin
  static Future<List<ChatMessage>> getConversation(String studentId) async {
    try {
      final db = await MongoDBService.getDatabase();
      final messages = await db.collection(DatabaseConfig.chatMessagesCollection)
          .find({'studentId': studentId})
          .toList();
      
      // Sort by timestamp ascending
      messages.sort((a, b) {
        final aTime = a['timestamp'] as DateTime;
        final bTime = b['timestamp'] as DateTime;
        return aTime.compareTo(bTime);
      });
      
      return messages.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (e) {
      print('Error getting conversation: $e');
      return [];
    }
  }

  // Get all students with pending messages
  static Future<List<String>> getStudentsWithPendingMessages() async {
    try {
      final db = await MongoDBService.getDatabase();
      final cursor = db.collection(DatabaseConfig.chatMessagesCollection)
          .find({'sender': 'student', 'isRead': false});
      
      final messages = await cursor.toList();
      final studentIds = messages
          .map((m) => m['studentId'] as String)
          .toSet()
          .toList();
      
      return studentIds;
    } catch (e) {
      print('Error getting students with pending messages: $e');
      return [];
    }
  }

  // Mark messages as read
  static Future<void> markAsRead(String studentId) async {
    try {
      final db = await MongoDBService.getDatabase();
      await db.collection(DatabaseConfig.chatMessagesCollection).update(
        where.eq('studentId', studentId).eq('isRead', false),
        modify.set('isRead', true),
        multiUpdate: true,
      );
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get all student IDs that have chat messages (chatted with admin)
  static Future<List<String>> getStudentsWithChatHistory() async {
    try {
      final db = await MongoDBService.getDatabase();
      final messages = await db.collection(DatabaseConfig.chatMessagesCollection)
          .find()
          .toList();
      
      // Get unique student IDs
      final studentIds = messages
          .map((m) => m['studentId'] as String)
          .toSet()
          .toList();
      
      return studentIds;
    } catch (e) {
      print('Error getting students with chat history: $e');
      return [];
    }
  }
}

