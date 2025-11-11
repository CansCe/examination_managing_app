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
              // Logger not needed here - silent fail is acceptable
              return ObjectId(); // Return a new ObjectId to avoid null
            }
          } else if (id is ObjectId) {
            return id;
          }
          return ObjectId(); // Default for invalid type
        }).toList();
      }

      // Handle both firstName/lastName and fullName formats
      String firstName = '';
      String lastName = '';
      if (map['fullName'] != null) {
        final fullName = map['fullName'].toString();
        final nameParts = fullName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      } else {
        firstName = map['firstName']?.toString() ?? '';
        lastName = map['lastName']?.toString() ?? '';
      }

      // Handle both rollNumber and studentId
      final rollNumber = map['rollNumber']?.toString() ?? 
                         map['studentId']?.toString() ?? '';

      return Student(
        id: map['_id']?.toString() ?? '',
        firstName: firstName,
        lastName: lastName,
        email: map['email']?.toString() ?? '',
        className: map['class']?.toString() ?? map['className']?.toString() ?? '',
        rollNumber: rollNumber,
        phoneNumber: map['phoneNumber']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        assignedExams: parsedAssignedExams,
      );
    } catch (e) {
      // Error will be rethrown - no logging needed in model layer
      rethrow;
    }
  }

  factory Student.fromJson(Map<String, dynamic> json) => Student.fromMap(json);

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