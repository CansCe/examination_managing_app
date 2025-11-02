import 'package:mongo_dart/mongo_dart.dart';
import '../models/index.dart';
import '../models/question.dart';
import '../utils/mock_data_export.dart';
import '../utils/mock_data_generator.dart';
import '../config/database_config.dart';

class MongoDBService {
  static Db? _db;
  
  // Collection names
  static const String _examsCollection = 'exams';
  static const String _studentsCollection = 'students';
  static const String _teachersCollection = 'teachers';

  static Future<Db> getDatabase() async {
    if (_db == null) {
      _db = await Db.create(DatabaseConfig.connectionString);
      await _db!.open();
    }
    return _db!;
  }

  // Initialize database connection
  static Future<void> init() async {
    try {
      final db = await getDatabase();
      // Create collections if they don't exist
      await db.createCollection(DatabaseConfig.examsCollection);
      await db.createCollection(DatabaseConfig.studentsCollection);
      await db.createCollection(DatabaseConfig.teachersCollection);
      await db.createCollection(DatabaseConfig.usersCollection);
      await db.createCollection(DatabaseConfig.questionsCollection);
    } catch (e) {
      print('Error initializing MongoDB: $e');
      rethrow;
    }
  }

  // Close database connection
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // Insert mock data
  static Future<void> insertMockData({
    required String collection,
    required int count,
  }) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Generate mock data using the new generator
      final mockData = await MockDataGenerator.generateBatch();

      // Get the appropriate data list based on collection
      List<Map<String, dynamic>> documents;
      switch (collection) {
        case _examsCollection:
          documents = mockData['exams']!;
          break;
        case _studentsCollection:
          documents = mockData['students']!;
          break;
        case _teachersCollection:
          documents = mockData['teachers']!;
          break;
        case 'questions':
          documents = mockData['questions']!;
          break;
        default:
          throw Exception('Invalid collection name: $collection');
      }

      // Clear existing data in the collection
      await _db!.collection(collection).drop();
      await _db!.createCollection(collection);

      // Insert new data
      if (documents.isNotEmpty) {
        await _db!.collection(collection).insertAll(documents);
        print('Successfully inserted ${documents.length} documents into $collection');
      }
    } catch (e) {
      print('Error inserting mock data: $e');
      rethrow;
    }
  }

  // Get all documents from a collection
  static Future<List<Map<String, dynamic>>> getAllDocuments(String collection) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final cursor = _db!.collection(collection).find();
      return await cursor.take(20).toList();
    } catch (e) {
      print('Error fetching documents: $e');
      rethrow;
    }
  }

  // Get document by ID
  static Future<Map<String, dynamic>?> getDocumentById(
    String collection,
    String id,
  ) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      return await _db!.collection(collection).findOne(where.id(id as ObjectId));
    } catch (e) {
      print('Error fetching document: $e');
      rethrow;
    }
  }

  // Update document
  static Future<bool> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> updates,
  ) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Create the update document with $set operator
      final updateDoc = {
        '\$set': {
          'updatedAt': DateTime.now().toIso8601String(),
          ...updates,
        }
      };

      final result = await _db!.collection(collection).update(
        where.id(id as ObjectId),
        updateDoc,
      );
      // Check if the update was successful by checking the 'ok' field
      return result['ok'] == 1;
    } catch (e) {
      print('Error updating document: $e');
      rethrow;
    }
  }

  // Delete document
  static Future<bool> deleteDocument(
    String collection,
    String id,
  ) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final result = await _db!.collection(collection).remove(where.id(id as ObjectId));
      // Check if the deletion was successful by checking the 'ok' field
      return result['ok'] == 1 && result['n'] > 0;
    } catch (e) {
      print('Error deleting document: $e');
      rethrow;
    }
  }

  // Search documents
  static Future<List<Map<String, dynamic>>> searchDocuments(
    String collection,
    Map<String, dynamic> query,
  ) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Create a selector based on the query parameters
      SelectorBuilder selector = where;
      query.forEach((key, value) {
        if (value is String) {
          // For string values, use case-insensitive regex search
          // Format the pattern with case-insensitive flag
          final pattern = '^$value\$';
          selector = selector.match(key, pattern, caseInsensitive: false);
        } else {
          // For other types, use exact match
          selector = selector.eq(key, value);
        }
      });

      final cursor = _db!.collection(collection).find(selector);
      return await cursor.take(20).toList();
    } catch (e) {
      print('Error searching documents: $e');
      rethrow;
    }
  }

  // Export default amounts (50 exams, 200 students, 20 teachers)
  static Future<void> exportDefaultMockData() async {
    await MockDataExport.exportMockData();
  }

  // Export custom amounts
  static Future<void> exportCustomMockData({
    required int examCount,
    required int studentCount,
    required int teacherCount,
  }) async {
    // Since we're using the new mock data generation system,
    // we'll just call the default export for now
    await MockDataExport.exportMockData();
  }

  // Load mock data from files
  static Future<void> loadMockData() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Clear existing collections first
      await clearCollections();

      // Load mock data from files
      final mockData = await MockDataExport.loadMockData();

      // Convert string IDs to ObjectIds and insert data
      final teachers = mockData['teachers']!.map((teacher) {
        return {
          '_id': teacher['_id'] is String 
              ? ObjectId.fromHexString(teacher['_id']) 
              : teacher['_id'],
          'firstName': teacher['firstName'],
          'lastName': teacher['lastName'],
          'email': teacher['email'],
          'username': teacher['username'],
          'password': teacher['password'],
          'department': teacher['department'],
          'subjects': teacher['subjects'],
          'createdExams': (teacher['createdExams'] as List).map((id) => 
              id is String ? ObjectId.fromHexString(id) : id).toList(),
        };
      }).toList();

      final students = mockData['students']!.map((student) {
        return {
          '_id': student['_id'] is String 
              ? ObjectId.fromHexString(student['_id']) 
              : student['_id'],
          'studentId': student['studentId'],
          'firstName': student['firstName'],
          'lastName': student['lastName'],
          'email': student['email'],
          'password': student['password'],
          'class': student['class'],
          'subjects': student['subjects'],
          'enrolledExams': (student['enrolledExams'] as List).map((id) => 
              id is String ? ObjectId.fromHexString(id) : id).toList(),
        };
      }).toList();

      final exams = mockData['exams']!.map((exam) {
        return {
          '_id': exam['_id'] is String 
              ? ObjectId.fromHexString(exam['_id']) 
              : exam['_id'],
          'title': exam['title'],
          'description': exam['description'],
          'subject': exam['subject'],
          'date': exam['date'] is String ? DateTime.parse(exam['date']) : exam['date'],
          'duration': exam['duration'],
          'maxStudents': exam['maxStudents'],
          'difficulty': exam['difficulty'],
          'status': exam['status'],
          'createdBy': exam['createdBy'] is String 
              ? ObjectId.fromHexString(exam['createdBy']) 
              : exam['createdBy'],
          'questions': (exam['questions'] as List).map((id) => 
              id is String ? ObjectId.fromHexString(id) : id).toList(),
          'createdAt': exam['createdAt'] is String ? DateTime.parse(exam['createdAt']) : exam['createdAt'],
          'updatedAt': exam['updatedAt'] is String ? DateTime.parse(exam['updatedAt']) : exam['updatedAt'],
        };
      }).toList();

      final questions = mockData['questions']!.map((question) {
        return {
          '_id': question['_id'] is String 
              ? ObjectId.fromHexString(question['_id']) 
              : question['_id'],
          'text': question['text'],
          'type': question['type'],
          'subject': question['subject'],
          'difficulty': question['difficulty'],
          'points': question['points'],
          'examId': question['examId'] is String 
              ? ObjectId.fromHexString(question['examId']) 
              : question['examId'],
          'options': question['options'],
          'correctAnswer': question['correctAnswer'],
          'createdAt': question['createdAt'] is String ? DateTime.parse(question['createdAt']) : question['createdAt'],
          'updatedAt': question['updatedAt'] is String ? DateTime.parse(question['updatedAt']) : question['updatedAt'],
        };
      }).toList();

      // Insert the converted data into collections
      if (teachers.isNotEmpty) {
        await _db!.collection(DatabaseConfig.teachersCollection).insertAll(teachers);
        print('Successfully inserted ${teachers.length} teachers');
      }

      if (students.isNotEmpty) {
        await _db!.collection(DatabaseConfig.studentsCollection).insertAll(students);
        print('Successfully inserted ${students.length} students');
      }

      if (exams.isNotEmpty) {
        await _db!.collection(DatabaseConfig.examsCollection).insertAll(exams);
        print('Successfully inserted ${exams.length} exams');
      }

      if (questions.isNotEmpty) {
        await _db!.collection(DatabaseConfig.questionsCollection).insertAll(questions);
        print('Successfully inserted ${questions.length} questions');
      }

      print('All mock data has been successfully loaded into MongoDB Atlas');
    } catch (e) {
      print('Error loading mock data: $e');
      rethrow;
    }
  }

  // Find a student by their student ID
  static Future<Map<String, dynamic>?> findStudentByStudentId(String studentId) async {
    try {
      final students = _db!.collection('students');
      final student = await students.findOne(where.eq('studentId', studentId));
      return student;
    } catch (e) {
      print('Error finding student: $e');
      rethrow;
    }
  }

  // Get student exams with pagination
  static Future<List<Exam>> getStudentExams({
    required String studentId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final db = await getDatabase();
      final studentsCollection = db.collection('students');
      final examsCollection = db.collection('exams');

      // First, get the student's class and subjects
      final student = await studentsCollection.findOne(
        where.eq('studentId', studentId),
      );

      if (student == null) {
        throw Exception('Student not found');
      }

      final studentClass = student['class'] as String? ?? '';
      // final studentSubjects = student['subjects'] != null
      //   ? List<String>.from(student['subjects'])
      //   : <String>[];

      // Find exams that match the student's class and subjects
      final query = where
          .eq('className', studentClass)
          .gte('date', DateTime.now().toIso8601String()) // Only future exams
          .sortBy('date', descending: false);

      final cursor = examsCollection.find(query);
      final exams = await cursor
          .skip(page * limit)
          .take(limit)
          .toList();

      return exams.map((e) => Exam.fromMap(e)).toList();
    } catch (e) {
      print('Error getting student exams: $e');
      rethrow;
    }
  }

  static Future<List<Exam>> findExams({
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final db = await getDatabase();
      final examsCollection = db.collection('exams');

      final cursor = examsCollection.find();
      final exams = await cursor
          .skip(page * limit)
          .take(limit)
          .toList();

      return exams.map((data) => Exam.fromMap(data)).toList();
    } catch (e) {
      print('Error finding exams: $e');
      rethrow;
    }
  }

  static Future<List<Student>> findStudents({
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final db = await getDatabase();
      final studentsCollection = db.collection('students');

      final cursor = studentsCollection.find();
      final students = await cursor
          .skip(page * limit)
          .take(limit)
          .toList();

      return students.map((data) => Student.fromMap(data)).toList();
    } catch (e) {
      print('Error finding students: $e');
      rethrow;
    }
  }

  static Future<List<Teacher>> findTeachers({
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final db = await getDatabase();
      final teachersCollection = db.collection('teachers');

      final cursor = teachersCollection.find();
      final teachers = await cursor
          .skip(page * limit)
          .take(limit)
          .toList();

      return teachers.map((data) {
        // Ensure all required fields are present and of correct type
        final Map<String, dynamic> teacherData = {
          '_id': data['_id'] is String 
              ? ObjectId.fromHexString(data['_id']) 
              : data['_id'] ?? ObjectId(),
          'firstName': data['firstName']?.toString() ?? '',
          'lastName': data['lastName']?.toString() ?? '',
          'email': data['email']?.toString() ?? '',
          'username': data['username']?.toString() ?? '',
          'password': data['password']?.toString() ?? '',
          'department': data['department']?.toString() ?? '',
          'subjects': (data['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [],
          'createdExams': (data['createdExams'] as List?)?.map((e) => e is String 
              ? ObjectId.fromHexString(e) 
              : e ?? ObjectId()).toList() ?? [],
        };
        return Teacher.fromMap(teacherData);
      }).toList();
    } catch (e) {
      print('Error finding teachers: $e');
      rethrow;
    }
  }

  static Future<List<Exam>> getTeacherExams({
    required String teacherId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final db = await getDatabase();
      final examsCollection = db.collection('exams');

      final query = where
          .eq('createdBy', teacherId)
          .sortBy('date', descending: true);

      final cursor = examsCollection.find(query);
      final exams = await cursor
          .skip(page * limit)
          .take(limit)
          .toList();

      return exams.map((data) => Exam.fromMap(data)).toList();
    } catch (e) {
      print('Error getting teacher exams: $e');
      rethrow;
    }
  }

  static Future<bool> updateExamStatus({
    required String examId,
    required String status,
    DateTime? newDate,
  }) async {
    try {
      final db = await getDatabase();
      final examsCollection = db.collection('exams');

      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (newDate != null) {
        updates['date'] = newDate.toIso8601String();
      }

      final result = await examsCollection.updateOne(
        where.id(ObjectId.fromHexString(examId)),
        modify.set('status', status)
            .set('updatedAt', DateTime.now().toIso8601String())
            .set('date', newDate?.toIso8601String()),
      );

      return result.isSuccess;
    } catch (e) {
      print('Error updating exam status: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> findTeacherByUsername(String username) async {
    try {
      final db = await getDatabase();
      final users = db.collection('users');
      
      final teacher = await users.findOne(
        where.and([
          where.eq('role', 'teacher'),
          where.or([
            where.eq('username', username),
            where.eq('email', username),
          ] as SelectorBuilder),
        ] as SelectorBuilder)
      );
      
      if (teacher != null) {
        // Ensure all required fields are present and of correct type
        return {
          '_id': teacher['_id'] is String 
              ? ObjectId.fromHexString(teacher['_id']) 
              : teacher['_id'] ?? ObjectId(),
          'firstName': teacher['firstName']?.toString() ?? '',
          'lastName': teacher['lastName']?.toString() ?? '',
          'email': teacher['email']?.toString() ?? '',
          'username': teacher['username']?.toString() ?? '',
          'password': teacher['password']?.toString() ?? '',
          'department': teacher['department']?.toString() ?? '',
          'subjects': (teacher['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [],
          'createdExams': (teacher['createdExams'] as List?)?.map((e) => e is String 
              ? ObjectId.fromHexString(e) 
              : e ?? ObjectId()).toList() ?? [],
        };
      }
      
      return null;
    } catch (e) {
      print('Error finding teacher by username: $e');
      return null;
    }
  }

  // Get all questions from the collection
  static Future<List<Question>> getAllQuestions() async {
    return getQuestionsBySubject('');
  }

  // Get questions by subject (if subject is empty, returns all questions)
  static Future<List<Question>> getQuestionsBySubject(String subject) async {
    try {
      final collection = _db!.collection('questions');
      final cursor = subject.isEmpty || subject == ''
          ? collection.find()
          : collection.find(where.eq('subject', subject));
      final questions = await cursor.toList();

      return questions.map((doc) {
        try {
          final id = doc['_id'] as ObjectId;
          final text = doc['text'] as String? ?? '';
          final questionText = doc['questionText'] as String? ?? text;
          final type = doc['type'] as String? ?? 'multiple_choice';
          final subject = doc['subject'] as String? ?? 'General';
          final topic = doc['topic'] as String? ?? 'General';
          final difficulty = doc['difficulty'] as String? ?? 'medium';
          final points = doc['points'] as int? ?? 1;
          final examId = doc['examId'] is String 
              ? ObjectId.fromHexString(doc['examId'] as String)
              : doc['examId'] as ObjectId? ?? ObjectId();
          final createdBy = doc['createdBy'] is String 
              ? ObjectId.fromHexString(doc['createdBy'] as String)
              : doc['createdBy'] as ObjectId? ?? ObjectId();
          final options = (doc['options'] as List<dynamic>?)?.cast<String>() ?? [];
          final correctAnswer = doc['correctAnswer'] as String? ?? '';
          final correctOptionIndex = doc['correctOptionIndex'] as int? ?? 0;
          final createdAt = doc['createdAt'] is String 
              ? DateTime.parse(doc['createdAt'] as String)
              : doc['createdAt'] as DateTime? ?? DateTime.now();
          final updatedAt = doc['updatedAt'] is String 
              ? DateTime.parse(doc['updatedAt'] as String)
              : doc['updatedAt'] as DateTime? ?? DateTime.now();

          return Question(
            id: id,
            text: text,
            questionText: questionText,
            type: type,
            subject: subject,
            topic: topic,
            difficulty: difficulty,
            points: points,
            examId: examId,
            createdBy: createdBy,
            options: options,
            correctAnswer: correctAnswer,
            correctOptionIndex: correctOptionIndex,
            createdAt: createdAt,
            updatedAt: updatedAt,
          );
        } catch (e) {
          print('Error converting question document: $e');
          print('Document data: $doc');
          rethrow;
        }
      }).toList();
    } catch (e) {
      print('Error getting questions by subject: $e');
      rethrow;
    }
  }

  // Get exam by ID
  static Future<Exam?> getExamById(ObjectId examId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final exam = await _db!.collection(_examsCollection)
          .findOne(where.id(examId));
      
      if (exam == null) {
        return null;
      }

      final Map<String, dynamic> examData = {
        '_id': exam['_id'] is String 
            ? ObjectId.fromHexString(exam['_id']) 
            : exam['_id'],
        'title': exam['title'] ?? '',
        'description': exam['description'] ?? '',
        'subject': exam['subject'] ?? '',
        'date': exam['date'] is String 
            ? DateTime.parse(exam['date']) 
            : exam['date'] ?? DateTime.now(),
        'duration': exam['duration'] ?? 60,
        'maxStudents': exam['maxStudents'] ?? 30,
        'difficulty': exam['difficulty'] ?? 'medium',
        'status': exam['status'] ?? 'draft',
        'questions': (exam['questions'] as List?)?.map((id) => 
            id is String ? ObjectId.fromHexString(id) : id).toList() ?? [],
        'createdAt': exam['createdAt'] is String 
            ? DateTime.parse(exam['createdAt']) 
            : exam['createdAt'] ?? DateTime.now(),
        'updatedAt': exam['updatedAt'] is String 
            ? DateTime.parse(exam['updatedAt']) 
            : exam['updatedAt'] ?? DateTime.now(),
      };

      return Exam.fromMap(examData);
    } catch (e) {
      print('Error getting exam by ID: $e');
      rethrow;
    }
  }

  // Get teacher name by ID
  static Future<String> getTeacherName(ObjectId teacherId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final teacher = await _db!.collection(_teachersCollection)
          .findOne(where.id(teacherId));
      
      if (teacher != null) {
        return '${teacher['firstName']} ${teacher['lastName']}';
      }
      return 'Unknown Teacher';
    } catch (e) {
      print('Error getting teacher name: $e');
      return 'Unknown Teacher';
    }
  }

  // Get exams
  static Future<List<Exam>> getExams() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final exams = await _db!.collection(_examsCollection).find().toList();
      final examsWithTeachers = <Exam>[];

      for (var exam in exams) {
        final Map<String, dynamic> examData = {
          '_id': exam['_id'] is String 
              ? ObjectId.fromHexString(exam['_id']) 
              : exam['_id'],
          'title': exam['title'] ?? '',
          'description': exam['description'] ?? '',
          'subject': exam['subject'] ?? '',
          'date': exam['date'] is String 
              ? DateTime.parse(exam['date']) 
              : exam['date'] ?? DateTime.now(),
          'duration': exam['duration'] ?? 60,
          'maxStudents': exam['maxStudents'] ?? 30,
          'difficulty': exam['difficulty'] ?? 'medium',
          'status': exam['status'] ?? 'draft',
          'questions': (exam['questions'] as List?)?.map((id) => 
              id is String ? ObjectId.fromHexString(id) : id).toList() ?? [],
          'createdAt': exam['createdAt'] is String 
              ? DateTime.parse(exam['createdAt']) 
              : exam['createdAt'] ?? DateTime.now(),
          'updatedAt': exam['updatedAt'] is String 
              ? DateTime.parse(exam['updatedAt']) 
              : exam['updatedAt'] ?? DateTime.now(),
        };

        examsWithTeachers.add(Exam.fromMap(examData));
      }

      return examsWithTeachers;
    } catch (e) {
      print('Error getting exams: $e');
      rethrow;
    }
  }

  // Create exam
  static Future<Exam> createExam(Exam exam) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final examMap = exam.toMap();
      examMap['_id'] = ObjectId();
      examMap['createdAt'] = DateTime.now();
      examMap['updatedAt'] = DateTime.now();

      await _db!.collection(_examsCollection).insertOne(examMap);
      return Exam.fromMap(examMap);
    } catch (e) {
      print('Error creating exam: $e');
      rethrow;
    }
  }

  static Future<bool> updateExam(Exam exam) async {
    try {
      final db = await getDatabase();
      final exams = db.collection('exams');
      
      await exams.updateOne(
        where.id(exam.id),
        exam.toMap()
      );
      
      return true;
    } catch (e) {
      print('Error updating exam: $e');
      return false;
    }
  }

  static Future<bool> deleteExam(ObjectId examId, ObjectId teacherId) async {
    try {
      final db = await getDatabase();
      final exams = db.collection('exams');
      final teachers = db.collection('teachers');
      
      // Delete the exam
      await exams.deleteOne(where.id(examId));
      
      // Remove exam ID from teacher's createdExams list
      await teachers.updateOne(
        where.id(teacherId),
        modify.pull('createdExams', examId)
      );
      
      return true;
    } catch (e) {
      print('Error deleting exam: $e');
      return false;
    }
  }

  static Future<bool> createQuestion(Question question) async {
    try {
      final db = await getDatabase();
      final questions = db.collection('questions');
      
      await questions.insert(question.toMap());
      return true;
    } catch (e) {
      print('Error creating question: $e');
      return false;
    }
  }

  static Future<bool> updateQuestion(Question question) async {
    try {
      final db = await getDatabase();
      final questions = db.collection('questions');
      
      await questions.updateOne(
        where.id(question.id),
        question.toMap()
      );
      
      return true;
    } catch (e) {
      print('Error updating question: $e');
      return false;
    }
  }

  static Future<Question?> getQuestionById(ObjectId questionId) async {
    try {
      final db = await getDatabase();
      final questions = db.collection('questions');
      
      final questionDoc = await questions.findOne(where.id(questionId));
      
      if (questionDoc == null) {
        return null;
      }
      
      return Question.fromMap(questionDoc);
    } catch (e) {
      print('Error getting question by ID: $e');
      return null;
    }
  }

  static Future<bool> deleteQuestion(ObjectId questionId) async {
    try {
      final db = await getDatabase();
      final questions = db.collection('questions');
      
      await questions.deleteOne(where.id(questionId));
      return true;
    } catch (e) {
      print('Error deleting question: $e');
      return false;
    }
  }

  static Future<void> clearCollections() async {
    try {
      final db = await getDatabase();
      print('DEBUG: Clearing teachers collection...');
      await db.collection('teachers').deleteMany({});
      print('DEBUG: Teachers collection count after clear: ${await db.collection('teachers').count()}');
      
      print('DEBUG: Clearing students collection...');
      await db.collection('students').deleteMany({});
      print('DEBUG: Students collection count after clear: ${await db.collection('students').count()}');

      print('DEBUG: Clearing exams collection...');
      await db.collection('exams').deleteMany({});
      print('DEBUG: Exams collection count after clear: ${await db.collection('exams').count()}');

      print('DEBUG: Clearing questions collection...');
      await db.collection('questions').deleteMany({});
      print('DEBUG: Questions collection count after clear: ${await db.collection('questions').count()}');
      
      print('DEBUG: All collections cleared.');
    } catch (e) {
      print('Error clearing collections: $e');
    }
  }

  static Future<void> insertTeachers(List<Map<String, dynamic>> teachers) async {
    try {
      final db = await getDatabase();
      await db.collection('teachers').insertAll(teachers);
    } catch (e) {
      print('Error inserting teachers: $e');
    }
  }

  static Future<void> insertStudents(List<Map<String, dynamic>> students) async {
    try {
      final db = await getDatabase();
      await db.collection('students').insertAll(students);
    } catch (e) {
      print('Error inserting students: $e');
    }
  }

  static Future<void> insertExams(List<Map<String, dynamic>> exams) async {
    try {
      final db = await getDatabase();
      await db.collection('exams').insertAll(exams);
    } catch (e) {
      print('Error inserting exams: $e');
    }
  }

  static Future<void> insertQuestions(List<Map<String, dynamic>> questions) async {
    try {
      final db = await getDatabase();
      await db.collection('questions').insertAll(questions);
    } catch (e) {
      print('Error inserting questions: $e');
    }
  }

  // static List<Map<String, dynamic>> findTeachers() {
  //   try {
  //     final db = getDatabase();
  //     final teachers = db.collection('teachers');
  //     return teachers.find().toList();
  //   } catch (e) {
  //     print('Error finding teachers: $e');
  //     return [];
  //   }
  // }

  // Get questions by their IDs
  static Future<List<Question>> getQuestionsByIds(List<ObjectId> questionIds) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }

    try {
      final cursor = _db!.collection('questions').find(
        where.eq('_id', {'\$in': questionIds})
      );
      
      final List<Map<String, dynamic>> questionMaps = await cursor.toList();
      return questionMaps.map((map) => Question.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching questions: $e');
      rethrow;
    }
  }

  // Initialize database with mock data
  static Future<void> initializeMockData() async {
    try {
      // Initialize collections
      await init();

      // Insert mock data for each collection
      await insertMockData(collection: _teachersCollection, count: 5);
      await insertMockData(collection: _studentsCollection, count: 20);
      await insertMockData(collection: _examsCollection, count: 15);
      await insertMockData(collection: 'questions', count: 50);

      print('Successfully initialized all mock data');
    } catch (e) {
      print('Error initializing mock data: $e');
      rethrow;
    }
  }
}
