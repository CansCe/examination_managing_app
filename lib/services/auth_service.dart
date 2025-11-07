import '../models/index.dart';
import 'api_service.dart';

class AuthService {
  static Future<User?> login({
    required String username,
    required String password,
  }) async {
    try {
      final api = ApiService();
      final result = await api.login(username: username, password: password);
      api.close();

      if (result == null) {
        return null;
      }

      final roleString = (result['role'] as String? ?? 'student').toLowerCase();
      final role = roleString == 'teacher'
          ? UserRole.teacher
          : roleString == 'admin'
              ? UserRole.admin
              : UserRole.student;

      return User(
        id: result['id']?.toString() ?? '',
        username: result['username']?.toString() ?? username,
        role: role,
        fullName: result['fullName']?.toString() ?? result['username']?.toString() ?? username,
      );
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
      final api = ApiService();
      final success = await api.changePassword(
        userId: userId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      api.close();
      return success;
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  static Future<User?> getCurrentUser(String userId) async {
    try {
      final api = ApiService();
      final result = await api.getCurrentUser(userId);
      api.close();

      if (result == null) {
        return null;
      }

      final roleString = (result['role'] as String? ?? 'student').toLowerCase();
      final role = roleString == 'teacher'
          ? UserRole.teacher
          : roleString == 'admin'
              ? UserRole.admin
              : UserRole.student;

      return User(
        id: result['id']?.toString() ?? userId,
        username: result['username']?.toString() ?? '',
        role: role,
        fullName: result['fullName']?.toString() ?? result['username']?.toString() ?? '',
      );
    } catch (e) {
      print('Error getting current user: $e');
      rethrow;
    }
  }
} 