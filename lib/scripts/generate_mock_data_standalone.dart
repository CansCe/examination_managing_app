import 'dart:io';
import 'dart:math';
import 'package:mongo_dart/mongo_dart.dart';

/// Standalone script to generate and upload mock data to MongoDB Atlas
/// 
/// This script uses ONLY pure Dart packages (no Flutter dependencies)
/// It can be run with: dart run lib/scripts/generate_mock_data_standalone.dart
/// 
/// This script will:
///   1. Connect directly to MongoDB Atlas
///   2. Drop the entire database
///   3. Generate fresh mock data
///   4. Upload all data to the cluster

// MongoDB connection configuration
const String connectionString =
    'mongodb+srv://admin1:jjNu8RzV5onpbb6T@clustertest.7nkaqoh.mongodb.net/exam_management?retryWrites=true&w=majority&appName=ClusterTest';
const String databaseName = 'exam_management';

// Collection names
const String teachersCollection = 'teachers';
const String studentsCollection = 'students';
const String examsCollection = 'exams';
const String questionsCollection = 'questions';
const String usersCollection = 'users';

final Random _random = Random();

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print('''
Standalone Mock Data Generator Script
=====================================

This script generates mock data and uploads it to MongoDB Atlas.
It uses ONLY pure Dart packages (no Flutter dependencies).

Usage:
  dart run lib/scripts/generate_mock_data_standalone.dart

The script will:
  1. Connect to MongoDB Atlas (exam_management database)
  2. Drop the entire database (WARNING: This deletes ALL existing data!)
  3. Generate fresh mock data (teachers, students, exams, questions, admins)
  4. Upload all generated data to the cluster

Options:
  --help, -h    Show this help message

Note: Make sure your MongoDB connection string is correct in the script.
''');
    exit(0);
  }

  Db? db;
  
  try {
    print('\n${'='.padRight(60, '=')}');
    print('STANDALONE MOCK DATA GENERATOR');
    print('='.padRight(60, '='));
    print('');
    
    print('WARNING: This will drop and recreate the entire database!');
    print('All existing data will be permanently deleted!\n');
    
    // Connect to MongoDB
    print('Connecting to MongoDB Atlas...');
    db = await Db.create(connectionString);
    await db.open();
    print('Connected successfully!\n');
    
    // Drop the entire database
    print('Dropping entire database: $databaseName');
    print('This will delete ALL data in the database!');
    await db.drop();
    print('Database dropped successfully\n');
    
    // Generate mock data
    print('Generating mock data...');
    final teachers = _generateTeachers();
    final examData = _generateExams(teachers);
    final exams = examData['exams'] as List<Map<String, dynamic>>;
    final questions = examData['questions'] as List<Map<String, dynamic>>;
    final students = _generateStudents(exams);
    final admins = _generateAdmins();
    
    print('Generated:');
    print('  - Teachers: ${teachers.length}');
    print('  - Students: ${students.length}');
    print('  - Exams: ${exams.length}');
    print('  - Questions: ${questions.length}');
    print('  - Admins: ${admins.length}\n');
    
    // Upload to MongoDB
    print('Uploading data to MongoDB...\n');
    
    // Upload teachers
    if (teachers.isNotEmpty) {
      print('Uploading ${teachers.length} teachers...');
      await db.collection(teachersCollection).insertAll(teachers);
      print('✓ Teachers uploaded');
    }
    
    // Upload students
    if (students.isNotEmpty) {
      print('Uploading ${students.length} students...');
      await db.collection(studentsCollection).insertAll(students);
      print('✓ Students uploaded');
    }
    
    // Upload exams
    if (exams.isNotEmpty) {
      print('Uploading ${exams.length} exams...');
      await db.collection(examsCollection).insertAll(exams);
      print('✓ Exams uploaded');
    }
    
    // Upload questions
    if (questions.isNotEmpty) {
      print('Uploading ${questions.length} questions...');
      await db.collection(questionsCollection).insertAll(questions);
      print('✓ Questions uploaded');
    }
    
    // Upload admins
    if (admins.isNotEmpty) {
      print('Uploading ${admins.length} admin users...');
      await db.collection(usersCollection).insertAll(admins);
      print('✓ Admins uploaded');
    }
    
    // Print summary
    print('\n${'='.padRight(60, '=')}');
    print('GENERATION COMPLETE');
    print('='.padRight(60, '='));
    print('\nFinal Summary:');
    print('  • Teachers: ${teachers.length}');
    print('  • Students: ${students.length}');
    print('  • Exams: ${exams.length}');
    print('  • Questions: ${questions.length}');
    print('  • Admins: ${admins.length}');
    print('\n✓ All data has been uploaded to MongoDB Atlas!');
    print('${'='.padRight(60, '=')}\n');
    
    exit(0);
  } catch (e, stackTrace) {
    print('\n${'='.padRight(60, '=')}');
    print('ERROR OCCURRED');
    print('='.padRight(60, '='));
    print('\nFailed to generate/upload mock data:');
    print('Error: $e');
    print('\nStack trace:');
    print(stackTrace);
    print('${'\n='.padRight(60, '=')}\n');
    
    exit(1);
  } finally {
    // Close the connection
    if (db != null) {
      await db.close();
    }
  }
}

// Generate teachers
List<Map<String, dynamic>> _generateTeachers() {
  final List<Map<String, dynamic>> teachers = [];
  const departments = ['Science', 'Mathematics', 'Computer Science', 'Arts', 'Languages'];
  const subjects = [
    ['Physics', 'Chemistry'],
    ['Algebra', 'Calculus'],
    ['Programming', 'Database'],
    ['Literature', 'History'],
    ['English', 'Spanish'],
  ];

  for (int i = 0; i < 5; i++) {
    final teacherId = ObjectId();
    final departmentIndex = i % departments.length;
    teachers.add({
      '_id': teacherId,
      'firstName': 'Teacher${i + 1}',
      'lastName': 'Last${i + 1}',
      'email': 'teacher${i + 1}@school.com',
      'username': 'teacher${i + 1}',
      'password': '12345678',
      'department': departments[departmentIndex],
      'subjects': subjects[departmentIndex],
      'createdExams': <ObjectId>[],
      'role': 'teacher',
    });
  }

  return teachers;
}

// Generate exams and questions
Map<String, dynamic> _generateExams(List<Map<String, dynamic>> teachers) {
  final List<Map<String, dynamic>> exams = [];
  final List<Map<String, dynamic>> questions = [];
  const examTypes = ['Midterm', 'Final', 'Quiz'];
  const difficulties = ['easy', 'medium', 'hard'];
  const subjects = ['Mathematics', 'Physics', 'Chemistry', 'Programming'];

  int questionIndex = 0;

  for (int i = 0; i < teachers.length; i++) {
    final teacher = teachers[i];
    final teacherId = teacher['_id'] as ObjectId;

    // Generate 3 exams per teacher
    for (int j = 0; j < 3; j++) {
      final examId = ObjectId();
      final examType = examTypes[j % examTypes.length];
      final subject = subjects[i % subjects.length];
      final examDate = DateTime.now().add(Duration(days: j + 1));

      // Generate 5 questions per exam
      final List<ObjectId> questionIds = [];
      for (int k = 0; k < 5; k++) {
        final questionId = ObjectId();
        questionIds.add(questionId);

        final question = {
          '_id': questionId,
          'questionText': 'Question ${questionIndex + 1}: What is the answer?',
          'type': 'multiple_choice',
          'subject': subject,
          'topic': 'Topic ${k + 1}',
          'difficulty': difficulties[k % difficulties.length],
          'points': 10,
          'options': ['Option A', 'Option B', 'Option C', 'Option D'],
          'correctAnswer': 'Option A',
          'correctOptionIndex': 0,
          'examId': examId,
          'createdBy': teacherId,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };
        questions.add(question);
        questionIndex++;
      }

      final exam = {
        '_id': examId,
        'title': '$examType Exam - $subject',
        'description': 'This is a $examType exam for $subject',
        'subject': subject,
        'difficulty': 'medium',
        'examDate': examDate,
        'examTime': '09:00',
        'duration': 60,
        'maxStudents': 30,
        'questions': questionIds,
        'createdBy': teacherId,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'status': 'scheduled',
      };
      exams.add(exam);

      // Update teacher's createdExams
      (teacher['createdExams'] as List<ObjectId>).add(examId);
    }
  }

  return {'exams': exams, 'questions': questions};
}

// Generate students
List<Map<String, dynamic>> _generateStudents(List<Map<String, dynamic>> exams) {
  final List<Map<String, dynamic>> students = [];
  final classes = List.generate(10, (i) => 'Class ${i + 1}');

  // Extract exam ObjectIds for assignment
  final List<ObjectId> allExamIds = exams.map((exam) => exam['_id'] as ObjectId).toList();

  for (int i = 0; i < 20; i++) {
    final studentId = _generateStudentId();
    
    // Assign a random subset of exams to each student
    final List<ObjectId> assignedExams = [];
    if (allExamIds.isNotEmpty) {
      final numExamsToAssign = _random.nextInt(3) + 1; // Assign 1 to 3 exams
      for (int j = 0; j < numExamsToAssign && j < allExamIds.length; j++) {
        assignedExams.add(allExamIds[_random.nextInt(allExamIds.length)]);
      }
    }

    students.add({
      '_id': ObjectId(),
      'studentId': studentId,
      'rollNumber': studentId,
      'firstName': 'Student${i + 1}',
      'lastName': 'Last${i + 1}',
      'email': 'student${i + 1}@example.com',
      'password': '12345678',
      'className': classes[i % classes.length],
      'class': classes[i % classes.length],
      'phoneNumber': '09${_random.nextInt(100000000).toString().padLeft(8, '0')}',
      'address': 'Address ${i + 1}',
      'assignedExams': assignedExams,
      'role': 'student',
    });
  }

  return students;
}

// Generate admin users
List<Map<String, dynamic>> _generateAdmins() {
  final List<Map<String, dynamic>> admins = [];
  
  for (int i = 1; i <= 2; i++) {
    final adminId = ObjectId();
    admins.add({
      '_id': adminId,
      'firstName': 'Admin$i',
      'lastName': 'Support',
      'email': 'admin$i@school.com',
      'username': 'admin$i',
      'password': '12345678',
      'fullName': 'Admin$i Support',
      'role': 'admin',
      'isActive': true,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
  }
  
  return admins;
}

// Generate a student ID (8 digits)
String _generateStudentId() {
  return List.generate(8, (_) => _random.nextInt(10)).join();
}

