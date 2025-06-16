import 'package:mongo_dart/mongo_dart.dart';
import '../models/index.dart';
import 'mongodb_service.dart';

class AuthService {
  static Future<User?> login({
    required String username,
    required String password,
  }) async {
    try {
      final db = await MongoDBService.getDatabase();
      final usersCollection = db.collection('users');

      // Try to find user by username/studentId first
      var user = await usersCollection.findOne({
        '\$or': [
          {'username': username},
          {'studentId': username},
        ],
        'password': password,
      });

      // If not found, try to find teacher by email
      user ??= await usersCollection.findOne({
          'email': username,
          'password': password,
          'role': 'teacher',
        });

      if (user != null) {
        return User(
          id: user['_id'].toString(),
          username: user['username'] ?? user['studentId'] ?? user['email'],
          role: user['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
          fullName: user['fullName'],
        );
      }
      return null;
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    // In a real app, you might want to:
    // 1. Clear any stored tokens
    // 2. Clear any cached user data
    // 3. Notify the server about the logout
    // For now, we'll just return
  }

  static Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final db = await MongoDBService.getDatabase();
      final usersCollection = db.collection('users');

      final result = await usersCollection.updateOne(
        where.id(ObjectId.fromHexString(userId)),
        modify.set('password', newPassword),
      );

      return result.isSuccess;
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  static Future<User?> getCurrentUser(String userId) async {
    try {
      final db = await MongoDBService.getDatabase();
      final usersCollection = db.collection('users');

      final user = await usersCollection.findOne(
        where.id(ObjectId.fromHexString(userId)),
      );

      if (user != null) {
        return User(
          id: user['_id'].toString(),
          username: user['username'] ?? user['studentId'] ?? user['email'],
          role: user['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
          fullName: user['fullName'],
        );
      }

      return null;
    } catch (e) {
      print('Error getting current user: $e');
      rethrow;
    }
  }
} 