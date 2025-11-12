import 'package:mongo_dart/mongo_dart.dart';
import 'question.dart';

class Exam {
  final ObjectId id;
  final String title;
  final String description;
  final String subject;
  final String difficulty;
  final DateTime examDate;
  final String examTime;
  final int duration;
  final int maxStudents;
  final List<ObjectId> questions;
  final ObjectId createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? status;
  final bool isDummy; // Flag to indicate if this is a dummy/test exam
  List<Question>? populatedQuestions;

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.difficulty,
    required this.examDate,
    required this.examTime,
    required this.duration,
    required this.maxStudents,
    required this.questions,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.status,
    this.isDummy = false,
    this.populatedQuestions,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'difficulty': difficulty,
      'examDate': examDate,
      'examTime': examTime,
      'duration': duration,
      'maxStudents': maxStudents,
      'questions': questions,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
      'isDummy': isDummy,
    };
  }

  /// Converts Exam to JSON-safe format for API calls
  /// Converts ObjectIds to hex strings and DateTimes to ISO strings
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'subject': subject,
      'difficulty': difficulty,
      'examDate': examDate.toIso8601String(),
      'examTime': examTime,
      'duration': duration,
      'maxStudents': maxStudents,
      'questions': questions.map((q) => q.toHexString()).toList(),
      'createdBy': createdBy.toHexString(),
      'status': status,
      'isDummy': isDummy,
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    // Handle ID conversion
    ObjectId examId;
    if (map['_id'] is String) {
      try {
        examId = ObjectId.fromHexString(map['_id']);
      } catch (e) {
        print('Error converting exam ID: ${map['_id']}');
        examId = ObjectId();
      }
    } else if (map['_id'] is ObjectId) {
      examId = map['_id'];
    } else {
      examId = ObjectId();
    }

    // Handle createdBy conversion
    ObjectId createdById;
    if (map['createdBy'] is String) {
      try {
        createdById = ObjectId.fromHexString(map['createdBy']);
      } catch (e) {
        print('Error converting createdBy ID: ${map['createdBy']}');
        createdById = ObjectId();
      }
    } else if (map['createdBy'] is ObjectId) {
      createdById = map['createdBy'];
    } else {
      createdById = ObjectId();
    }

    // Handle questions list conversion
    List<ObjectId> questionIds = [];
    if (map['questions'] is List) {
      questionIds = (map['questions'] as List).map((q) {
        if (q is String) {
          try {
            return ObjectId.fromHexString(q);
          } catch (e) {
            print('Error converting question ID: $q');
            return ObjectId();
          }
        } else if (q is ObjectId) {
          return q;
        }
        return ObjectId();
      }).toList();
    }

    // Parse exam time (now stored as String)
    // Handle "NaN" for dummy exams that can start at any time
    String parsedExamTime;
    try {
      if (map['examTime'] == null) {
        parsedExamTime = '09:00'; // Default to 09:00 if null
      } else if (map['examTime'] is String) {
        final timeStr = map['examTime'] as String;
        // Check if it's "NaN" (for dummy exams)
        if (timeStr.toUpperCase() == 'NAN' || timeStr == 'NaN') {
          parsedExamTime = 'NaN';
        } else if (timeStr.contains(':')) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
              parsedExamTime = timeStr;
            } else {
              parsedExamTime = '09:00';
            }
          } else {
            parsedExamTime = '09:00';
          }
        } else {
          parsedExamTime = '09:00';
        }
      } else {
        parsedExamTime = '09:00';
      }
    } catch (e) {
      print('Error parsing exam time: $e');
      parsedExamTime = '09:00';
    }
    
    // Parse isDummy flag
    final isDummy = map['isDummy'] == true || map['isDummy'] == 'true' || map['isDummy'] == 1;

    return Exam(
      id: examId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: map['subject'] ?? 'General',
      difficulty: map['difficulty'] ?? 'medium',
      examDate: map['examDate'] is String 
          ? DateTime.parse(map['examDate']) 
          : map['examDate'] ?? DateTime.now(),
      examTime: parsedExamTime,
      duration: map['duration'] ?? 60,
      maxStudents: map['maxStudents'] ?? 30,
      questions: questionIds,
      createdBy: createdById,
      createdAt: map['createdAt'] is String 
          ? DateTime.parse(map['createdAt']) 
          : map['createdAt'] ?? DateTime.now(),
      updatedAt: map['updatedAt'] is String 
          ? DateTime.parse(map['updatedAt']) 
          : map['updatedAt'] ?? DateTime.now(),
      status: map['status'] as String?,
      isDummy: isDummy,
      populatedQuestions: null, // This field will be populated separately
    );
  }

  // Calculate exam start DateTime
  // Returns null for dummy exams (can start at any time)
  DateTime? getExamStartDateTime() {
    // Dummy exams can start at any time
    if (isDummy || examTime.toUpperCase() == 'NAN') {
      return null;
    }
    
    try {
      final timeParts = examTime.split(':');
      if (timeParts.length == 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(
          examDate.year,
          examDate.month,
          examDate.day,
          hour,
          minute,
        );
      }
    } catch (e) {
      // Default to 9:00 AM if parsing fails
    }
    return DateTime(
      examDate.year,
      examDate.month,
      examDate.day,
      9,
      0,
    );
  }

  // Calculate exam end DateTime (start time + duration)
  // Returns null for dummy exams
  DateTime? getExamEndDateTime() {
    final startTime = getExamStartDateTime();
    if (startTime == null) return null; // Dummy exam
    return startTime.add(Duration(minutes: duration));
  }

  // Check if exam has ended
  // Always returns false for dummy exams (they can be taken at any time)
  bool isExamFinished() {
    if (isDummy || examTime.toUpperCase() == 'NAN') {
      return false; // Dummy exams never "finish"
    }
    final endTime = getExamEndDateTime();
    if (endTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(endTime);
  }

  // Check if exam has started (current time >= start time)
  // Always returns true for dummy exams (they can start at any time)
  bool isExamStarted() {
    if (isDummy || examTime.toUpperCase() == 'NAN') {
      return true; // Dummy exams can always be started
    }
    final startTime = getExamStartDateTime();
    if (startTime == null) return true;
    final now = DateTime.now();
    return now.isAfter(startTime) || now.isAtSameMomentAs(startTime);
  }

  // Get exam status based on current time
  String getExamStatus() {
    if (status != null && (status == 'cancelled' || status == 'delayed')) {
      return status!;
    }
    
    // Dummy exams are always available
    if (isDummy || examTime.toUpperCase() == 'NAN') {
      return 'available';
    }
    
    final now = DateTime.now();
    final startTime = getExamStartDateTime();
    final endTime = getExamEndDateTime();
    
    if (startTime == null || endTime == null) {
      return 'available';
    }

    if (now.isBefore(startTime)) {
      return 'scheduled';
    } else if (now.isAfter(endTime)) {
      return 'finished';
    } else {
      return 'ongoing';
    }
  }
} 