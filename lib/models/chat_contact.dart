import 'package:mongo_dart/mongo_dart.dart';
import 'student.dart';
import 'teacher.dart';

/// Unified chat contact that can represent either a Student or Teacher
class ChatContact {
  final String id;
  final String fullName;
  final String email;
  final String role; // 'student' or 'teacher'
  final String? rollNumber; // For students
  final String? department; // For teachers
  final String? className; // For students

  ChatContact({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.rollNumber,
    this.department,
    this.className,
  });

  factory ChatContact.fromStudent(Student student) {
    return ChatContact(
      id: student.id,
      fullName: student.fullName,
      email: student.email,
      role: 'student',
      rollNumber: student.rollNumber,
      className: student.className,
    );
  }

  factory ChatContact.fromTeacher(Teacher teacher) {
    return ChatContact(
      id: teacher.id.toHexString(),
      fullName: teacher.fullName,
      email: teacher.email,
      role: 'teacher',
      department: teacher.department,
    );
  }

  /// Convert back to Student (if role is 'student')
  Student? toStudent() {
    if (role != 'student') return null;
    return Student(
      id: id,
      firstName: fullName.split(' ').first,
      lastName: fullName.split(' ').length > 1 ? fullName.split(' ').sublist(1).join(' ') : '',
      email: email,
      className: className ?? '',
      rollNumber: rollNumber ?? '',
      phoneNumber: '',
      address: '',
      assignedExams: [],
    );
  }

  /// Convert back to Teacher (if role is 'teacher')
  Teacher? toTeacher() {
    if (role != 'teacher') return null;
    return Teacher(
      id: ObjectId.fromHexString(id),
      firstName: fullName.split(' ').first,
      lastName: fullName.split(' ').length > 1 ? fullName.split(' ').sublist(1).join(' ') : '',
      email: email,
      username: email.split('@').first,
      password: '', // Not needed for chat
      department: department ?? '',
      subjects: [],
      createdExams: [],
    );
  }

  /// Get display identifier (rollNumber for students, department for teachers)
  String get displayIdentifier {
    if (role == 'student' && rollNumber != null) {
      return rollNumber!;
    } else if (role == 'teacher' && department != null) {
      return department!;
    }
    return email;
  }
}

