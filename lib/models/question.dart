import 'package:mongo_dart/mongo_dart.dart';

class Question {
  final ObjectId id;
  final String text;
  final String questionText;
  final String type;
  final String subject;
  final String topic;
  final String difficulty;
  final int points;
  final ObjectId examId;
  final ObjectId createdBy;
  final List<String> options;
  final String correctAnswer;
  final int correctOptionIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.text,
    required this.questionText,
    required this.type,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.points,
    required this.examId,
    required this.createdBy,
    required this.options,
    required this.correctAnswer,
    required this.correctOptionIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Question to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'text': text,
      'questionText': questionText,
      'type': type,
      'subject': subject,
      'topic': topic,
      'difficulty': difficulty,
      'points': points,
      'examId': examId,
      'createdBy': createdBy,
      'options': options,
      'correctAnswer': correctAnswer,
      'correctOptionIndex': correctOptionIndex,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create Question from Map (from database)
  factory Question.fromMap(Map<String, dynamic> map) {
    // Handle ID conversion
    ObjectId questionId;
    if (map['_id'] is String) {
      try {
        questionId = ObjectId.fromHexString(map['_id']);
      } catch (e) {
        print('Error converting question ID: ${map['_id']}');
        questionId = ObjectId();
      }
    } else if (map['_id'] is ObjectId) {
      questionId = map['_id'];
    } else {
      questionId = ObjectId();
    }

    // Handle examId conversion
    ObjectId examId;
    if (map['examId'] is String) {
      try {
        examId = ObjectId.fromHexString(map['examId']);
      } catch (e) {
        print('Error converting exam ID: ${map['examId']}');
        examId = ObjectId();
      }
    } else if (map['examId'] is ObjectId) {
      examId = map['examId'];
    } else {
      examId = ObjectId();
    }

    // Handle createdBy conversion
    ObjectId createdBy;
    if (map['createdBy'] is String) {
      try {
        createdBy = ObjectId.fromHexString(map['createdBy']);
      } catch (e) {
        print('Error converting createdBy ID: ${map['createdBy']}');
        createdBy = ObjectId();
      }
    } else if (map['createdBy'] is ObjectId) {
      createdBy = map['createdBy'];
    } else {
      createdBy = ObjectId();
    }

    // Ensure options is a List<String>
    List<String> questionOptions = [];
    if (map['options'] != null) {
      if (map['options'] is List) {
        questionOptions = (map['options'] as List).map((e) => e.toString()).toList();
      } else if (map['options'] is String) {
        questionOptions = (map['options'] as String).split(',');
      }
    }

    // Get the question text, preferring questionText over text
    final String questionText = map['questionText'] ?? map['text'] ?? 'Question text not available';

    return Question(
      id: questionId,
      text: questionText,
      questionText: questionText,
      type: map['type'] ?? 'multiple_choice',
      subject: map['subject'] ?? 'General',
      topic: map['topic'] ?? 'General',
      difficulty: map['difficulty'] ?? 'medium',
      points: map['points'] ?? 1,
      examId: examId,
      createdBy: createdBy,
      options: questionOptions,
      correctAnswer: map['correctAnswer'] ?? '',
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      createdAt: map['createdAt'] is String 
          ? DateTime.parse(map['createdAt']) 
          : map['createdAt'] ?? DateTime.now(),
      updatedAt: map['updatedAt'] is String 
          ? DateTime.parse(map['updatedAt']) 
          : map['updatedAt'] ?? DateTime.now(),
    );
  }

  // Create a copy of Question with some fields updated
  Question copyWith({
    ObjectId? id,
    String? text,
    String? questionText,
    String? type,
    String? subject,
    String? topic,
    String? difficulty,
    int? points,
    ObjectId? examId,
    ObjectId? createdBy,
    List<String>? options,
    String? correctAnswer,
    int? correctOptionIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      questionText: questionText ?? this.questionText,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      examId: examId ?? this.examId,
      createdBy: createdBy ?? this.createdBy,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          questionText == other.questionText &&
          type == other.type &&
          subject == other.subject &&
          topic == other.topic &&
          difficulty == other.difficulty &&
          points == other.points &&
          examId == other.examId &&
          createdBy == other.createdBy &&
          options == other.options &&
          correctAnswer == other.correctAnswer &&
          correctOptionIndex == other.correctOptionIndex;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      questionText.hashCode ^
      type.hashCode ^
      subject.hashCode ^
      topic.hashCode ^
      difficulty.hashCode ^
      points.hashCode ^
      examId.hashCode ^
      createdBy.hashCode ^
      options.hashCode ^
      correctAnswer.hashCode ^
      correctOptionIndex.hashCode;
} 