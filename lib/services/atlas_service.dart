import 'package:mongo_dart/mongo_dart.dart';
import '../config/database_config.dart';
import '../models/index.dart';
import '../utils/mock_data_generator.dart';
import 'index.dart';
import 'api_service.dart';

class DummyExamSetup {
  final Exam exam;
  final Map<String, dynamic>? assignedStudent;
  final Map<String, dynamic>? submission;

  DummyExamSetup({
    required this.exam,
    this.assignedStudent,
    this.submission,
  });
}

class AtlasService {
  static Db? _db;
  static bool _isInitialized = false;

  // Initialize connection to MongoDB Atlas
  static Future<void> init() async {
    if (!_isInitialized) {
      // REST-based implementation no longer requires a persistent MongoDB connection.
      // Preserve existing API for legacy callers.
      _isInitialized = true;
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
      if (documents.isEmpty) {
        print('⚠ Warning: Attempted to upload empty list to $collection');
        return [];
      }
      
      print('  → Inserting ${documents.length} documents into $collection...');
      final result = await _db!.collection(collection).insertAll(documents);
      
      final List<String> ids = [];
      if (result.containsKey('insertedIds')) {
        final insertedIds = result['insertedIds'] as List;
        for (var id in insertedIds) {
          ids.add(id.toString());
        }
      }
      
      // Verify insertion by counting documents
      try {
        final count = await _db!.collection(collection).count();
        print('  → Collection $collection now has $count document(s)');
      } catch (e) {
        print('  → Note: Could not verify document count: $e');
      }
      
      if (ids.length != documents.length) {
        print('⚠ Warning: Expected ${documents.length} inserted IDs but got ${ids.length}');
      }
      
      return ids;
    } catch (e, stackTrace) {
      print("❌ Error uploading multiple documents to $collection: $e");
      print("Stack trace: $stackTrace");
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

  // Delete multiple documents by filter
  static Future<int> deleteDocuments(String collection, Map<String, dynamic> filter) async {
    await _ensureConnection();
    try {
      SelectorBuilder selector = where;
      filter.forEach((key, value) {
        selector = selector.eq(key, value);
      });
      final result = await _db!.collection(collection).remove(selector);
      return result['n'] ?? 0; // Return number of deleted documents
    } catch (e) {
      print('Error deleting documents from $collection: $e');
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
    try {
      return MongoDBService.getQuestionsByIds(questionIds);
    } catch (e) {
      print('Error getting questions by IDs: $e');
      rethrow;
    }
  }

  // Find all teachers with pagination
  static Future<List<Teacher>> findTeachers({int page = 0, int limit = 20}) async {
    try {
      final api = ApiService();
      final data = await api.getTeachers(page: page, limit: limit);
      api.close();
      return data.map((doc) => Teacher.fromMap(doc)).toList();
    } catch (e) {
      print('Error finding teachers: $e');
      rethrow;
    }
  }

  // Find all students with pagination
  static Future<List<Student>> findStudents({int page = 0, int limit = 20}) async {
    try {
      final api = ApiService();
      final data = await api.getStudents(page: page, limit: limit);
      api.close();
      return data.map((doc) => Student.fromMap(doc)).toList();
    } catch (e) {
      print('Error finding students: $e');
      rethrow;
    }
  }

  // Find all exams with pagination
  static Future<List<Exam>> findExams({int page = 0, int limit = 20}) async {
    try {
      final api = ApiService();
      final documents = await api.getExams(page: page, limit: limit);
      api.close();

      final List<Exam> exams = documents.map((doc) => Exam.fromMap(doc)).toList();
      for (final exam in exams) {
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await MongoDBService.getQuestionsByIds(exam.questions);
        }
      }
      return exams;
    } catch (e) {
      print('Error finding exams: $e');
      rethrow;
    }
  }

  static Future<DummyExamSetup> createDummyExamScenario({
    required String teacherId,
    bool assignSampleStudent = true,
  }) async {
    final api = ApiService();
    try {
      final now = DateTime.now();
      final subject = 'Demo Subject';
      final questionTemplates = [
        {
          'questionText': 'What is the capital of France?',
          'options': ['Paris', 'London', 'Berlin', 'Madrid'],
          'correctAnswer': 'Paris',
          'difficulty': 'easy',
          'points': 1,
        },
        {
          'questionText': 'Solve: 12 + 8 = ?',
          'options': ['18', '20', '16', '22'],
          'correctAnswer': '20',
          'difficulty': 'easy',
          'points': 1,
        },
        {
          'questionText': 'Water freezes at what temperature (°C)?',
          'options': ['0', '100', '-10', '50'],
          'correctAnswer': '0',
          'difficulty': 'medium',
          'points': 2,
        },
      ];

      final questionIds = <String>[];
      final gradingTemplates = <Map<String, dynamic>>[];

      for (final template in questionTemplates) {
        final payload = {
          'text': template['questionText'],
          'questionText': template['questionText'],
          'type': 'multiple-choice',
          'subject': subject,
          'topic': 'General Knowledge',
          'difficulty': template['difficulty'],
          'options': template['options'],
          'correctAnswer': template['correctAnswer'],
          'points': template['points'],
          'createdBy': teacherId,
        };

        final insertedId = await api.createQuestion(payload);
        questionIds.add(insertedId);
        gradingTemplates.add({
          'id': insertedId,
          'points': template['points'],
          'correctAnswer': template['correctAnswer'],
        });
      }

      final examPayload = {
        'title': 'Demo Exam ${now.millisecondsSinceEpoch}',
        'description': 'Automatically generated exam for quick testing.',
        'subject': subject,
        'difficulty': 'medium',
        'examDate': now.add(const Duration(days: 1)).toIso8601String(),
        'examTime': '09:00',
        'duration': 45,
        'maxStudents': 30,
        'questions': questionIds,
        'createdBy': teacherId,
        'status': 'scheduled',
      };

      final insertedExamId = await api.createExam(examPayload);
      final examMap = await api.getExam(insertedExamId);
      final exam = Exam.fromMap(examMap);

      Map<String, dynamic>? assignedStudent;
      Map<String, dynamic>? submission;

      if (assignSampleStudent) {
        final students = await api.getStudents(limit: 1);
        if (students.isNotEmpty) {
          assignedStudent = students.first;
          final studentId = (assignedStudent['_id'] ?? assignedStudent['id'])?.toString();
          if (studentId != null && studentId.length == 24) {
            await api.assignStudentToExam(insertedExamId, studentId);

            final answers = <String, String>{};
            for (var index = 0; index < gradingTemplates.length; index++) {
              answers['$index'] = gradingTemplates[index]['correctAnswer'] as String;
            }

            final submissionResponse = await api.submitExamAnswers(
              examId: insertedExamId,
              studentId: studentId,
              answers: answers,
              questions: gradingTemplates,
              isTimeUp: false,
            );
            submission = submissionResponse['data'] as Map<String, dynamic>? ?? submissionResponse;
          }
        }
      }

      return DummyExamSetup(
        exam: exam,
        assignedStudent: assignedStudent,
        submission: submission,
      );
    } catch (e) {
      print('Error creating dummy exam scenario: $e');
      rethrow;
    } finally {
      api.close();
    }
  }

  // Find teacher by username
  static Future<Map<String, dynamic>?> findTeacherByUsername(String fullName) async {
    await _ensureConnection();
    try {
      // Split the full name into first and last name
      final nameParts = fullName.split(' ');
      if (nameParts.length < 2) {
        print('Invalid name format: $fullName');
        return null;
      }
      
      final firstName = nameParts[0];
      final lastName = nameParts[1];
      
      print('Searching for teacher with firstName: $firstName, lastName: $lastName');
      
      final teacher = await _db!.collection(DatabaseConfig.teachersCollection)
          .findOne(where
            .eq('firstName', firstName)
            .eq('lastName', lastName));
            
      if (teacher == null) {
        print('Teacher not found with name: $fullName');
      } else {
        print('Found teacher: ${teacher['_id']}');
      }
      
      return teacher;
    } catch (e) {
      print('Error finding teacher by name: $e');
      rethrow;
    }
  }

  // Get teacher's exams with pagination
  static Future<List<Exam>> getTeacherExams({
    required String teacherId, // Use as string for lookup
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final api = ApiService();
      final data = await api.getTeacherExams(
        teacherId: teacherId,
        page: page,
        limit: limit,
      );
      api.close();

      final exams = data.map((doc) => Exam.fromMap(doc)).toList();

      for (final exam in exams) {
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await MongoDBService.getQuestionsByIds(exam.questions);
        }
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
    try {
      final api = ApiService();
      final data = await api.getStudentExams(
        studentId: studentId,
        page: page,
        limit: limit,
      );
      api.close();

      final exams = data.map((doc) => Exam.fromMap(doc)).toList();

      for (final exam in exams) {
        if (exam.questions.isNotEmpty) {
          exam.populatedQuestions = await MongoDBService.getQuestionsByIds(exam.questions);
        }
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
    try {
      final api = ApiService();
      final success = await api.updateExamStatus(examId, status);
      api.close();
      return success;
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
    try {
      final api = ApiService();
      final payload = {
        'status': status,
        'examDate': newDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final success = await api.updateExam(examId, payload);
      api.close();
      return success;
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

  // Assign a student to an exam (add exam to student's assignedExams)
  static Future<bool> assignStudentToExam({
    required String studentId,
    required String examId,
  }) async {
    try {
      final api = ApiService();
      final success = await api.assignStudentToExam(examId, studentId);
      api.close();
      return success;
    } catch (e) {
      print("Error assigning student to exam: $e");
      rethrow;
    }
  }

  // Unassign a student from an exam (remove exam from student's assignedExams)
  static Future<bool> unassignStudentFromExam({
    required String studentId,
    required String examId,
  }) async {
    try {
      final api = ApiService();
      final success = await api.unassignStudentFromExam(examId, studentId);
      api.close();
      return success;
    } catch (e) {
      print("Error unassigning student from exam: $e");
      rethrow;
    }
  }

  // Get students assigned to an exam
  static Future<List<Student>> getStudentsAssignedToExam({
    required String examId,
    int limit = 1000,
  }) async {
    try {
      final api = ApiService();
      final data = await api.getStudentsAssignedToExam(examId);
      api.close();

      return data.take(limit).map((doc) => Student.fromMap(doc)).toList();
    } catch (e) {
      print('Error getting students assigned to exam: $e');
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

  // Drop the entire database
  static Future<void> dropDatabase() async {
    await _ensureConnection();
    try {
      print('\n⚠ WARNING: Dropping entire database: ${DatabaseConfig.databaseName}');
      print('This will delete ALL data in the database!');
      
      // Drop the entire database
      await _db!.drop();
      print('✓ Database dropped successfully');
      
      // Close the connection
      await close();
      _isInitialized = false;
      
      // Reconnect to the database (it will be recreated automatically when we access it)
      print('Reconnecting to database...');
      await init();
      
      // Ensure collections exist (they'll be created automatically on first insert, but let's be explicit)
      print('Ensuring collections exist...');
      try {
        await _db!.createCollection(DatabaseConfig.teachersCollection);
        await _db!.createCollection(DatabaseConfig.studentsCollection);
        await _db!.createCollection(DatabaseConfig.examsCollection);
        await _db!.createCollection(DatabaseConfig.questionsCollection);
        await _db!.createCollection(DatabaseConfig.usersCollection);
        await _db!.createCollection(DatabaseConfig.chatMessagesCollection);
        print('✓ All collections ensured');
      } catch (e) {
        // Collections might already exist or will be created on insert, that's okay
        print('Note: Some collections may already exist (will be created on first insert if needed)');
      }
      
      print('✓ Database recreated and ready for new data');
    } catch (e, stackTrace) {
      print('❌ Error dropping database: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to drop database: $e');
    }
  }

  // Clear all collections
  static Future<void> clearAllCollections() async {
    await _ensureConnection();
    try {
      print('Clearing all collections in database: ${DatabaseConfig.databaseName}...');
      
      // Drop and recreate teachers collection
      try {
        await _db!.collection(DatabaseConfig.teachersCollection).drop();
      } catch (e) {
        // Collection might not exist, that's okay
        print('Note: Teachers collection did not exist or already dropped');
      }
      await _db!.createCollection(DatabaseConfig.teachersCollection);
      print('✓ Teachers collection cleared');
      
      // Drop and recreate students collection
      try {
        await _db!.collection(DatabaseConfig.studentsCollection).drop();
      } catch (e) {
        print('Note: Students collection did not exist or already dropped');
      }
      await _db!.createCollection(DatabaseConfig.studentsCollection);
      print('✓ Students collection cleared');
      
      // Drop and recreate exams collection
      try {
        await _db!.collection(DatabaseConfig.examsCollection).drop();
      } catch (e) {
        print('Note: Exams collection did not exist or already dropped');
      }
      await _db!.createCollection(DatabaseConfig.examsCollection);
      print('✓ Exams collection cleared');
      
      // Drop and recreate questions collection
      try {
        await _db!.collection(DatabaseConfig.questionsCollection).drop();
      } catch (e) {
        print('Note: Questions collection did not exist or already dropped');
      }
      await _db!.createCollection(DatabaseConfig.questionsCollection);
      print('✓ Questions collection cleared');
      
      // Ensure chatMessages collection exists (don't clear it)
      try {
        await _db!.createCollection(DatabaseConfig.chatMessagesCollection);
        print('✓ ChatMessages collection ensured');
      } catch (e) {
        // Collection might already exist, that's okay
        print('Note: ChatMessages collection already exists');
      }
      
      // Note: users collection is not cleared here to preserve other user data
      // Admin users will be cleared and replaced separately in generateBatch
      
      print('✓ All collections cleared successfully');
    } catch (e) {
      print('❌ Error clearing collections: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Failed to clear collections: $e');
    }
  }

  // Submit exam answers with auto-grading
  static Future<Map<String, dynamic>> submitExamAnswers({
    required String examId,
    required String studentId,
    required Map<int, String> answers, // Map of question index to answer
    required DateTime submittedAt,
    bool isTimeUp = false,
    required List<Question> questions, // Questions to compare answers against
  }) async {
    try {
      final api = ApiService();

      final formattedAnswers = <String, String>{};
      answers.forEach((index, value) {
        formattedAnswers[index.toString()] = value;
      });

      final questionPayloads = questions.map((q) {
        return {
          'id': q.id.toHexString(),
          'correctAnswer': q.correctAnswer,
          'points': q.points,
        };
      }).toList();

      final response = await api.submitExamAnswers(
        examId: examId,
        studentId: studentId,
        answers: formattedAnswers,
        questions: questionPayloads,
        isTimeUp: isTimeUp,
      );
      api.close();

      return response['data'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      print('Error submitting exam answers: $e');
      rethrow;
    }
  }

  // Get exam results for a student
  static Future<Map<String, dynamic>?> getExamResult({
    required String examId,
    required String studentId,
  }) async {
    await _ensureConnection();
    try {
      final examObjectId = ObjectId.fromHexString(examId);
      final studentObjectId = ObjectId.fromHexString(studentId);
      
      final result = await _db!.collection(DatabaseConfig.examResultsCollection)
          .findOne(where
            .eq('examId', examObjectId)
            .eq('studentId', studentObjectId));
      
      return result;
    } catch (e) {
      print('Error getting exam result: $e');
      rethrow;
    }
  }

  // Generate and insert mock data
  static Future<void> generateAndInsertMockData() async {
    try {
      // First clear all existing data
      await clearAllCollections();
      
      print('Generating mock data...');
      // Skip automatic upload since we handle insertion manually here
      final mockData = await MockDataGenerator.generateBatch(uploadToMongoDB: false);
      
      print('Inserting teachers...');
      await _db!.collection(DatabaseConfig.teachersCollection).insertAll(mockData['teachers']!);
      
      print('Inserting students...');
      await _db!.collection(DatabaseConfig.studentsCollection).insertAll(mockData['students']!);
      
      print('Inserting exams...');
      await _db!.collection(DatabaseConfig.examsCollection).insertAll(mockData['exams']!);
      
      print('Inserting questions...');
      await _db!.collection(DatabaseConfig.questionsCollection).insertAll(mockData['questions']!);
      
      // Insert admin users
      if (mockData['admins'] != null && (mockData['admins'] as List).isNotEmpty) {
        print('Inserting admins...');
        await _db!.collection(DatabaseConfig.usersCollection).insertAll(mockData['admins']!);
        print('✓ Inserted ${(mockData['admins'] as List).length} admin users');
      }
      
      print('Mock data inserted successfully');
    } catch (e) {
      print('Error generating and inserting mock data: $e');
      throw Exception('Failed to generate and insert mock data: $e');
    }
  }
} 