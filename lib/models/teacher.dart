import 'package:mongo_dart/mongo_dart.dart';

class Teacher {
  final ObjectId id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final String department;
  final List<String> subjects;
  final List<ObjectId> createdExams;

  Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.department,
    required this.subjects,
    required this.createdExams,
  });

  factory Teacher.fromMap(Map<String, dynamic> map) {
    // Handle _id conversion
    ObjectId teacherId;
    if (map['_id'] is String) {
      try {
        teacherId = ObjectId.fromHexString(map['_id']);
      } catch (e) {
        print('Error converting teacher ID: ${map['_id']}');
        teacherId = ObjectId();
      }
    } else if (map['_id'] is ObjectId) {
      teacherId = map['_id'];
    } else {
      teacherId = ObjectId();
    }

    // Handle createdExams conversion
    List<ObjectId> examIds = [];
    if (map['createdExams'] is List) {
      examIds = (map['createdExams'] as List).map((examId) {
        if (examId is String) {
          try {
            return ObjectId.fromHexString(examId);
          } catch (e) {
            print('Error converting exam ID: $examId');
            return ObjectId();
          }
        } else if (examId is ObjectId) {
          return examId;
        }
        return ObjectId();
      }).toList();
    }

    return Teacher(
      id: teacherId,
      firstName: map['firstName']?.toString() ?? '',
      lastName: map['lastName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      subjects: (map['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [],
      createdExams: examIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'username': username,
      'password': password,
      'department': department,
      'subjects': subjects,
      'createdExams': createdExams,
    };
  }

  String get fullName => '$firstName $lastName';
}