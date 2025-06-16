import 'package:mongo_dart/mongo_dart.dart';
import 'package:exam_management_app/models/question.dart';

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
    final String parsedExamTime = map['examTime'] as String? ?? '09:00'; // Default to 09:00 if not found

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
      populatedQuestions: null, // This field will be populated separately
    );
  }
} 