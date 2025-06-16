import 'package:mongo_dart/mongo_dart.dart'; // Import ObjectId

class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String className;
  final String rollNumber;
  final String phoneNumber;
  final String address;
  final List<ObjectId> assignedExams;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.className,
    required this.rollNumber,
    required this.phoneNumber,
    required this.address,
    required this.assignedExams,
  });

  factory Student.fromMap(Map<String, dynamic> map) {
    try {
      List<ObjectId> parsedAssignedExams = [];
      if (map['assignedExams'] is List) {
        parsedAssignedExams = (map['assignedExams'] as List).map((id) {
          if (id is String) {
            try {
              return ObjectId.fromHexString(id);
            } catch (e) {
              print('Error converting assigned exam ID: $id');
              return ObjectId(); // Return a new ObjectId to avoid null
            }
          } else if (id is ObjectId) {
            return id;
          }
          return ObjectId(); // Default for invalid type
        }).toList();
      }

      return Student(
        id: map['_id']?.toString() ?? '',
        firstName: map['firstName']?.toString() ?? '',
        lastName: map['lastName']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        className: map['class']?.toString() ?? '',
        rollNumber: map['rollNumber']?.toString() ?? '',
        phoneNumber: map['phoneNumber']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        assignedExams: parsedAssignedExams,
      );
    } catch (e) {
      print('Error parsing Student from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'class': className,
      'rollNumber': rollNumber,
      'phoneNumber': phoneNumber,
      'address': address,
      'assignedExams': assignedExams,
    };
  }

  String get fullName => '$firstName $lastName';
} 