enum UserRole {
  student,
  teacher,
}

class User {
  final String id;
  final String username;
  final UserRole role;
  final String fullName;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.fullName,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id'].toString(),
      username: map['username'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${map['role']}',
        orElse: () => UserRole.student,
      ),
      fullName: map['fullName'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'username': username,
      'role': role.toString().split('.').last,
      'fullName': fullName,
    };
  }
} 