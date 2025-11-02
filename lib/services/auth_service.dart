import 'package:mongo_dart/mongo_dart.dart';
import '../models/index.dart';
import 'mongodb_service.dart';
import '../config/database_config.dart';

class AuthService {
  static Future<User?> login({
    required String username,
    required String password,
  }) async {
    try {
      final db = await MongoDBService.getDatabase();
      
      // Try to find student first
      var user = await db.collection(DatabaseConfig.studentsCollection).findOne({
        '\$or': [
          {'username': username},
          {'studentId': username},
        ],
        'password': password,
      });

      // If not found, try to find teacher
      user ??= await db.collection(DatabaseConfig.teachersCollection).findOne({
          '\$or': [
            {'username': username},
            {'email': username},
          ],
          'password': password,
        });

      // If not found, try to find admin in users collection
      user ??= await db.collection(DatabaseConfig.usersCollection).findOne({
          '\$or': [
            {'username': username},
            {'email': username},
          ],
          'password': password,
          'role': 'admin',
        });

      if (user != null) {
        // Determine role based on collection and fields
        UserRole role;
        if (user.containsKey('role') && user['role'] == 'admin') {
          role = UserRole.admin;
        } else if (user.containsKey('department')) {
          role = UserRole.teacher;
        } else {
          role = UserRole.student;
        }
        
        return User(
          id: user['_id'].toHexString(),
          username: user['username'] ?? user['studentId'] ?? user['email'],
          role: role,
          fullName: user['fullName'] ?? '${user['firstName']} ${user['lastName']}',
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
      
      // Try to update in students collection first
      var result = await db.collection(DatabaseConfig.studentsCollection).updateOne(
        where.id(ObjectId.fromHexString(userId)),
        modify.set('password', newPassword),
      );

      // If not found in students, try teachers collection
      if (!result.isSuccess) {
        result = await db.collection(DatabaseConfig.teachersCollection).updateOne(
          where.id(ObjectId.fromHexString(userId)),
          modify.set('password', newPassword),
        );
      }

      return result.isSuccess;
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  static Future<User?> getCurrentUser(String userId) async {
    try {
      final db = await MongoDBService.getDatabase();
      
      // Try to find in students collection first
      var user = await db.collection(DatabaseConfig.studentsCollection).findOne(
        where.id(ObjectId.fromHexString(userId)),
      );

      // If not found, try teachers collection
      user ??= await db.collection(DatabaseConfig.teachersCollection).findOne(
          where.id(ObjectId.fromHexString(userId)),
        );

      // If not found, try users collection (for admins)
      user ??= await db.collection(DatabaseConfig.usersCollection).findOne(
          where.id(ObjectId.fromHexString(userId)),
        );

      if (user != null) {
        // Determine role based on collection and fields
        UserRole role;
        if (user.containsKey('role') && user['role'] == 'admin') {
          role = UserRole.admin;
        } else if (user.containsKey('department')) {
          role = UserRole.teacher;
        } else {
          role = UserRole.student;
        }
        
        return User(
          id: user['_id'].toHexString(),
          username: user['username'] ?? user['studentId'] ?? user['email'],
          role: role,
          fullName: user['fullName'] ?? '${user['firstName']} ${user['lastName']}',
        );
      }

      return null;
    } catch (e) {
      print('Error getting current user: $e');
      rethrow;
    }
  }
} 