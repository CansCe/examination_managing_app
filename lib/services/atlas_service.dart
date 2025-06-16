import 'package:mongo_dart/mongo_dart.dart';
import '../config/database_config.dart';
import '../models/exam.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/question.dart';

class AtlasService {
  static Db? _db;
  static bool _isInitialized = false;

  // Initialize connection to MongoDB Atlas
  static Future<void> init() async {
    if (!_isInitialized) {
      try {
        _db = await Db.create(DatabaseConfig.connectionString);
        await _db!.open();
        _isInitialized = true;
        print('Successfully connected to MongoDB Atlas');
      } catch (e) {
        print("Error connecting to MongoDB Atlas: $e");
        rethrow;
      }
    }
  }

  // Close the database connection
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      print('MongoDB Atlas connection closed');
    }
  }

  // Fetch all documents from a collection
  static Future<List<Map<String, dynamic>>> fetchAll(String collection) async {
    await _ensureConnection();
    try {
      final cursor = _db!.collection(collection).find();
      return await cursor.toList();
    } catch (e) {
      print('Error fetching from $collection: $e');
      rethrow;
    }
  }

  // Fetch a single document by ID
  static Future<Map<String, dynamic>?> fetchById(String collection, String id) async {
    await _ensureConnection();
    try {
      return await _db!.collection(collection).findOne(where.id(ObjectId.fromHexString(id)));
    } catch (e) {
      print('Error fetching document from $collection: $e');
      rethrow;
    }
  }

  // Upload a single document
  static Future<String> uploadDocument(String collection, Map<String, dynamic> document) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(collection).insert(document);
      return result['_id'].toString();
    } catch (e) {
      print('Error uploading to $collection: $e');
      rethrow;
    }
  }

  // Upload multiple documents
  static Future<List<String>> uploadMany(String collection, List<Map<String, dynamic>> documents) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(collection).insertAll(documents);
      final List<String> ids = [];
      if (result.containsKey('insertedIds')) {
        final insertedIds = result['insertedIds'] as List;
        for (var id in insertedIds) {
          ids.add(id.toString());
        }
      }
      return ids;
    } catch (e) {
      print("Error uploading multiple documents to $collection: $e");
      rethrow;
    }
  }

  // Update a document
  static Future<bool> updateDocument(String collection, String id, Map<String, dynamic> updates) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(collection).update(
        where.id(ObjectId.fromHexString(id)),
        {'\$set': updates},
      );
      return result['ok'] == 1;
    } catch (e) {
      print('Error updating document in $collection: $e');
      rethrow;
    }
  }

  // Delete a document
  static Future<bool> deleteDocument(String collection, String id) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(collection).remove(
        where.id(ObjectId.fromHexString(id)),
      );
      return result['ok'] == 1;
    } catch (e) {
      print('Error deleting document from $collection: $e');
      rethrow;
    }
  }

  // Search documents with filters
  static Future<List<Map<String, dynamic>>> search(
    String collection, {
    Map<String, dynamic>? filters,
    Map<String, int>? sort,
    int? limit,
    int? skip,
  }) async {
    await _ensureConnection();
    try {
      SelectorBuilder selector = where;
      
      // Apply filters if provided
      if (filters != null) {
        filters.forEach((key, value) {
          if (value is String) {
            selector = selector.match(key, value, caseInsensitive: true);
          } else {
            selector = selector.eq(key, value);
          }
        });
      }

      // Apply sorting if provided
      if (sort != null) {
        sort.forEach((field, direction) {
          // Ensure direction is either 1 (ascending) or -1 (descending)
          final sortOrder = direction == 1 || direction == -1 ? direction : (direction > 0 ? 1 : -1);
          // The sortBy method in mongo_dart expects a boolean for descending (true for descending, false for ascending)
          // So, if sortOrder is -1 (descending), pass true. Otherwise (for 1, ascending), pass false.
          // This also handles the case where an invalid direction was provided and corrected by the line above.
          bool descending = sortOrder == -1;
          selector = selector.sortBy(field, descending: descending);
        });
      }

      // Apply pagination
      if (skip != null) {
        selector = selector.skip(skip);
      }
      if (limit != null) {
        selector = selector.limit(limit);
      }

      final cursor = _db!.collection(collection).find(selector);
      return await cursor.toList();
    } catch (e) {
      print('Error searching in $collection: $e');
      rethrow;
    }
  }

  // Helper method to ensure connection is established
  static Future<void> _ensureConnection() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // Specific methods for each collection type

  // Exams
  static Future<List<Exam>> fetchAllExams() async {
    final data = await fetchAll(DatabaseConfig.examsCollection);
    return data.map((doc) => Exam.fromMap(doc)).toList();
  }

  static Future<Exam?> fetchExamById(String id) async {
    final doc = await fetchById(DatabaseConfig.examsCollection, id);
    if (doc == null) {
      return null;
    }

    final exam = Exam.fromMap(doc);

    if (exam.questions.isNotEmpty) {
      exam.populatedQuestions = await getQuestionsByIds(exam.questions);
    }
    return exam;
  }

  static Future<String> uploadExam(Exam exam) async {
    return await uploadDocument(DatabaseConfig.examsCollection, exam.toMap());
  }

  // Students
  static Future<List<Student>> fetchAllStudents() async {
    final data = await fetchAll(DatabaseConfig.studentsCollection);
    return data.map((doc) => Student.fromMap(doc)).toList();
  }

  static Future<Student?> fetchStudentById(String id) async {
    final doc = await fetchById(DatabaseConfig.studentsCollection, id);
    return doc != null ? Student.fromMap(doc) : null;
  }

  static Future<String> uploadStudent(Student student) async {
    return await uploadDocument(DatabaseConfig.studentsCollection, student.toMap());
  }

  // Teachers
  static Future<List<Teacher>> fetchAllTeachers() async {
    final data = await fetchAll(DatabaseConfig.teachersCollection);
    return data.map((doc) => Teacher.fromMap(doc)).toList();
  }

  static Future<Teacher?> fetchTeacherById(String id) async {
    final doc = await fetchById(DatabaseConfig.teachersCollection, id);
    return doc != null ? Teacher.fromMap(doc) : null;
  }

  static Future<String> uploadTeacher(Teacher teacher) async {
    return await uploadDocument(DatabaseConfig.teachersCollection, teacher.toMap());
  }

  // Questions
  static Future<List<Question>> fetchAllQuestions() async {
    final data = await fetchAll(DatabaseConfig.questionsCollection);
    return data.map((doc) => Question.fromMap(doc)).toList();
  }

  static Future<Question?> fetchQuestionById(String id) async {
    final doc = await fetchById(DatabaseConfig.questionsCollection, id);
    return doc != null ? Question.fromMap(doc) : null;
  }

  static Future<String> uploadQuestion(Question question) async {
    return await uploadDocument(DatabaseConfig.questionsCollection, question.toMap());
  }

  // Get questions by their IDs
  static Future<List<Question>> getQuestionsByIds(List<ObjectId> questionIds) async {
    await _ensureConnection();
    try {
      final documents = await _db!.collection(DatabaseConfig.questionsCollection)
          .find(where.oneFrom('_id', questionIds))
          .toList();
      
      return documents.map((doc) {
        // Convert ObjectId to String for the id field
        final Map<String, dynamic> questionData = Map<String, dynamic>.from(doc);
        questionData['id'] = doc['_id'].toString();
        return Question.fromMap(questionData);
      }).toList();
    } catch (e) {
      print('Error getting questions by IDs: $e');
      rethrow;
    }
  }

  // Find all teachers with pagination
  static Future<List<Teacher>> findTeachers({int page = 0, int limit = 20}) async {
    await _ensureConnection();
    try {
      final documents = await _db!.collection(DatabaseConfig.teachersCollection)
          .find(where)
          .skip(page * limit)
          .take(limit)
          .toList();
      
      return documents.map((doc) {
        final Map<String, dynamic> teacherData = Map<String, dynamic>.from(doc);
        teacherData['id'] = doc['_id'].toString();
        return Teacher.fromMap(teacherData);
      }).toList();
    } catch (e) {
      print('Error finding teachers: $e');
      rethrow;
    }
  }

  // Find all students with pagination
  static Future<List<Student>> findStudents({int page = 0, int limit = 20}) async {
    await _ensureConnection();
    try {
      final documents = await _db!.collection(DatabaseConfig.studentsCollection)
          .find(where)
          .skip(page * limit)
          .take(limit)
          .toList();
      
      return documents.map((doc) {
        final Map<String, dynamic> studentData = Map<String, dynamic>.from(doc);
        studentData['id'] = doc['_id'].toString();
        return Student.fromMap(studentData);
      }).toList();
    } catch (e) {
      print('Error finding students: $e');
      rethrow;
    }
  }

  // Find all exams with pagination
  static Future<List<Exam>> findExams({int page = 0, int limit = 20}) async {
    await _ensureConnection();
    try {
      final documents = await _db!.collection(DatabaseConfig.examsCollection)
          .find(where)
          .skip(page * limit)
          .take(limit)
          .toList();
      
      final List<Exam> exams = [];
      for (var doc in documents) {
        final exam = Exam.fromMap(doc);
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await getQuestionsByIds(exam.questions);
        }
        exams.add(exam);
      }
      return exams;
    } catch (e) {
      print('Error finding exams: $e');
      rethrow;
    }
  }

  // Find teacher by username
  static Future<Map<String, dynamic>?> findTeacherByUsername(String username) async {
    await _ensureConnection();
    try {
      final teacher = await _db!.collection(DatabaseConfig.teachersCollection)
          .findOne(where.eq('username', username));
      return teacher;
    } catch (e) {
      print('Error finding teacher by username: $e');
      rethrow;
    }
  }

  // Get teacher's exams with pagination
  static Future<List<Exam>> getTeacherExams({
    required String teacherId,
    int page = 0,
    int limit = 20,
  }) async {
    await _ensureConnection();
    try {
      final teacherObjectId = ObjectId.fromHexString(teacherId);

      final documents = await _db!.collection(DatabaseConfig.examsCollection)
          .find(where.eq('createdBy', teacherObjectId))
          .skip(page * limit)
          .take(limit)
          .toList();
      
      final List<Exam> exams = [];
      for (var doc in documents) {
        final exam = Exam.fromMap(doc);
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await getQuestionsByIds(exam.questions);
        }
        exams.add(exam);
      }
      return exams;
    } catch (e) {
      print('Error getting teacher exams: $e');
      rethrow;
    }
  }

  // Get student's exams with pagination
  static Future<List<Exam>> getStudentExams({
    required String studentId,
    int page = 0,
    int limit = 20,
  }) async {
    await _ensureConnection();
    try {
      // First get the student's assigned exams
      final student = await _db!.collection(DatabaseConfig.studentsCollection)
          .findOne(where.eq('studentId', studentId));
      
      if (student == null) {
        return [];
      }

      final List<ObjectId> assignedExamIds = [];
      if (student['assignedExams'] is List) {
        for (var id in student['assignedExams'] as List) {
          if (id is String) {
            try {
              assignedExamIds.add(ObjectId.fromHexString(id));
            } catch (e) {
              print('Warning: Invalid ObjectId string in assignedExams: $id - $e');
              // Optionally, skip this ID or handle it differently
            }
          } else if (id is ObjectId) {
            assignedExamIds.add(id);
          } else {
            print('Warning: Unexpected type in assignedExams list: $id');
          }
        }
      }

      if (assignedExamIds.isEmpty) {
        return [];
      }

      // Then get the exam details
      final documents = await _db!.collection(DatabaseConfig.examsCollection)
          .find(where.oneFrom('_id', assignedExamIds))
          .skip(page * limit)
          .take(limit)
          .toList();
      
      final List<Exam> exams = [];
      for (var doc in documents) {
        final exam = Exam.fromMap(doc);
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await getQuestionsByIds(exam.questions);
        }
        exams.add(exam);
      }
      return exams;
    } catch (e) {
      print('Error getting student exams: $e');
      rethrow;
    }
  }

  // Update exam status
  static Future<bool> updateExamStatus({
    required String examId,
    required String status,
  }) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(DatabaseConfig.examsCollection).updateOne(
        where.id(ObjectId.fromHexString(examId)),
        modify
          .set('status', status)
          .set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      print("Error updating exam status: $e");
      rethrow;
    }
  }

  // Update exam with date and status
  static Future<bool> updateExam({
    required String examId,
    required String status,
    required DateTime newDate,
  }) async {
    await _ensureConnection();
    try {
      final result = await _db!.collection(DatabaseConfig.examsCollection).updateOne(
        where.id(ObjectId.fromHexString(examId)),
        modify
          .set('status', status)
          .set('examDate', newDate.toIso8601String())
          .set('updatedAt', DateTime.now().toIso8601String()),
      );
      return result.isSuccess;
    } catch (e) {
      print("Error updating exam: $e");
      rethrow;
    }
  }

  // Update teacher
  static Future<bool> updateTeacher({
    required String teacherId,
    String? name,
    String? email,
    String? phone,
    String? department,
    String? specialization,
  }) async {
    await _ensureConnection();
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;
      if (department != null) updateData['department'] = department;
      if (specialization != null) updateData['specialization'] = specialization;

      var modifier = modify;
      updateData.forEach((key, value) {
        modifier = modifier.set(key, value);
      });

      final result = await _db!.collection(DatabaseConfig.teachersCollection).updateOne(
        where.id(ObjectId.fromHexString(teacherId)),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      print("Error updating teacher: $e");
      rethrow;
    }
  }

  // Update student
  static Future<bool> updateStudent({
    required String studentId,
    String? name,
    String? email,
    String? phone,
    String? grade,
    String? section,
    List<String>? enrolledExams,
  }) async {
    await _ensureConnection();
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;
      if (grade != null) updateData['grade'] = grade;
      if (section != null) updateData['section'] = section;
      if (enrolledExams != null) updateData['enrolledExams'] = enrolledExams;

      var modifier = modify;
      updateData.forEach((key, value) {
        modifier = modifier.set(key, value);
      });

      final result = await _db!.collection(DatabaseConfig.studentsCollection).updateOne(
        where.id(ObjectId.fromHexString(studentId)),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      print("Error updating student: $e");
      rethrow;
    }
  }

  // Update question
  static Future<bool> updateQuestion({
    required String questionId,
    String? text,
    String? type,
    String? subject,
    String? topic,
    String? difficulty,
    int? points,
    List<String>? options,
    String? correctAnswer,
    int? correctOptionIndex,
  }) async {
    await _ensureConnection();
    try {
      final updateData = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (text != null) updateData['text'] = text;
      if (type != null) updateData['type'] = type;
      if (subject != null) updateData['subject'] = subject;
      if (topic != null) updateData['topic'] = topic;
      if (difficulty != null) updateData['difficulty'] = difficulty;
      if (points != null) updateData['points'] = points;
      if (options != null) updateData['options'] = options;
      if (correctAnswer != null) updateData['correctAnswer'] = correctAnswer;
      if (correctOptionIndex != null) updateData['correctOptionIndex'] = correctOptionIndex;

      var modifier = modify;
      updateData.forEach((key, value) {
        modifier = modifier.set(key, value);
      });

      final result = await _db!.collection(DatabaseConfig.questionsCollection).updateOne(
        where.id(ObjectId.fromHexString(questionId)),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      print("Error updating question: $e");
      rethrow;
    }
  }
} 