import 'dart:io';
import 'dart:math';
import 'package:mongo_dart/mongo_dart.dart';
import '../config/database_config.dart';

/// Standalone script to generate and upload mock data to MongoDB Atlas
/// 
/// This script uses ONLY pure Dart packages (no Flutter dependencies)
/// It can be run with: dart run lib/scripts/generate_mock_data_standalone.dart
/// 
/// Database Structure:
/// - Classes: Each class is like a university subject (30-40 students, 1 teacher)
/// - Students: Can be enrolled in multiple classes
/// - Teachers: Can teach multiple classes that match their subjects
/// - Exams: Created for specific classes
/// - Exam Results: Store student scores for PDF export
/// 
/// Note: Connection string is read from database_config.dart

// Collection names (using from config)
const String teachersCollection = DatabaseConfig.teachersCollection;
const String studentsCollection = DatabaseConfig.studentsCollection;
const String examsCollection = DatabaseConfig.examsCollection;
const String questionsCollection = DatabaseConfig.questionsCollection;
const String usersCollection = DatabaseConfig.usersCollection;
const String examResultsCollection = DatabaseConfig.examResultsCollection;
const String classesCollection = DatabaseConfig.classesCollection;

final Random _random = Random();
int _studentIdCounter = 1; // Counter for generating sequential student IDs

// Configuration
const int NUM_CLASSES = 10; // Number of classes (subjects)
const int STUDENTS_PER_CLASS_MIN = 30;
const int STUDENTS_PER_CLASS_MAX = 40;
const int NUM_TEACHERS = 10; // Total teachers (some may not teach any class)
const int NUM_STUDENTS = 200; // Total students (will be distributed across classes)
const int EXAMS_PER_CLASS = 3; // Midterm, Final, Quiz per class
const int QUESTIONS_PER_EXAM = 10;
const int QUESTIONS_IN_DATABANK = 500; // Total questions in question bank
const int STUDENT_CLASSES_MIN = 2; // Minimum classes per student
const int STUDENT_CLASSES_MAX = 4; // Maximum classes per student

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print('''
Standalone Mock Data Generator Script
=====================================

This script generates mock data for a university-style exam management system:
- Classes (subjects) with 30-40 students each
- Students enrolled in multiple classes
- Teachers teaching classes matching their subjects
- Exams created for specific classes
- Exam results stored for PDF export

Usage:
  dart run lib/scripts/generate_mock_data_standalone.dart

The script will:
  1. Connect to MongoDB Atlas (exam_management database)
  2. Drop the entire database (WARNING: This deletes ALL existing data!)
  3. Generate fresh mock data (classes, teachers, students, exams, questions, results)
  4. Upload all generated data to the cluster

Options:
  --help, -h    Show this help message

Note: Make sure your MongoDB connection string is correct in lib/config/database_config.dart
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
    print("All existing data will be permanently deleted!\n");
    
    // Connect to MongoDB using connection string from config
    print('Connecting to MongoDB Atlas...');
    print('Using connection string from database_config.dart');
    db = await Db.create(DatabaseConfig.connectionString);
    await db.open();
    print('Connected successfully!\n');
    
    // Drop the entire database
    print('Dropping entire database: ${DatabaseConfig.databaseName}');
    print('This will delete ALL data in the database!');
    await db.drop();
    print('Database dropped successfully\n');
    
    // Generate mock data in order
    print('Generating mock data...');
    print('Step 1: Generating teachers...');
    final teachers = _generateTeachers();
    
    print('Step 2: Generating classes (subjects)...');
    final classes = _generateClasses(teachers);
    
    print('Step 3: Generating students...');
    final students = _generateStudents();
    
    print('Step 4: Assigning students to classes...');
    final studentClassAssignments = _assignStudentsToClasses(students, classes);
    
    print('Step 5: Creating classes collection with student lists...');
    final classesData = _createClassesCollection(classes, studentClassAssignments);
    
    print('Step 6: Generating question bank...');
    final questionBank = _generateQuestionBank(teachers);
    
    print('Step 7: Generating exams and questions for classes...');
    final examData = _generateExamsForClasses(classes, teachers, questionBank);
    final exams = examData['exams'] as List<Map<String, dynamic>>;
    final examQuestions = examData['questions'] as List<Map<String, dynamic>>;
    
    // Combine question bank with exam questions
    final allQuestions = [...questionBank, ...examQuestions];
    
    print('Step 8: Assigning students to exams based on class enrollment...');
    _assignStudentsToExams(students, exams, studentClassAssignments);
    
    print('Step 9: Generating exam results...');
    final examResults = _generateExamResults(students, exams, studentClassAssignments);
    
    print('Step 10: Generating admin users...');
    final admins = _generateAdmins();
    
    print('\nGenerated:');
    print('  - Classes: ${classesData.length}');
    print('  - Teachers: ${teachers.length} (${teachers.length - classes.length} not assigned to any class)');
    print('  - Students: ${students.length}');
    print('  - Exams: ${exams.length}');
    print('  - Questions in Bank: ${questionBank.length}');
    print('  - Exam Questions: ${examQuestions.length}');
    print('  - Total Questions: ${allQuestions.length}');
    print('  - Exam Results: ${examResults.length}');
    print('  - Admins: ${admins.length}\n');
    
    // Upload to MongoDB
    print('Uploading data to MongoDB...\n');
    
    // Upload teachers
    if (teachers.isNotEmpty) {
      print('Uploading ${teachers.length} teachers...');
      await db.collection(teachersCollection).insertAll(teachers);
      print('✓ Teachers uploaded');
    }
    
    // Upload students (with class assignments)
    if (students.isNotEmpty) {
      print('Uploading ${students.length} students...');
      await db.collection(studentsCollection).insertAll(students);
      print('✓ Students uploaded');
    }
    
    // Upload classes collection
    if (classesData.isNotEmpty) {
      print('Uploading ${classesData.length} classes...');
      await db.collection(classesCollection).insertAll(classesData);
      print('✓ Classes uploaded');
    }
    
    // Upload exams
    if (exams.isNotEmpty) {
      print('Uploading ${exams.length} exams...');
      await db.collection(examsCollection).insertAll(exams);
      print('✓ Exams uploaded');
    }
    
    // Upload questions (question bank + exam questions)
    if (allQuestions.isNotEmpty) {
      print('Uploading ${allQuestions.length} questions (${questionBank.length} in bank + ${examQuestions.length} exam-specific)...');
      await db.collection(questionsCollection).insertAll(allQuestions);
      print('✓ Questions uploaded');
    }
    
    // Upload exam results
    if (examResults.isNotEmpty) {
      print('Uploading ${examResults.length} exam results...');
      await db.collection(examResultsCollection).insertAll(examResults);
      print('✓ Exam results uploaded');
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
    print('  • Classes: ${classesData.length}');
    print('  • Teachers: ${teachers.length} (${teachers.length - classes.length} not teaching)');
    print('  • Students: ${students.length}');
    print('  • Exams: ${exams.length}');
    print('  • Questions: ${allQuestions.length} (${questionBank.length} in bank)');
    print('  • Exam Results: ${examResults.length}');
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

// Generate teachers with subjects
List<Map<String, dynamic>> _generateTeachers() {
  final List<Map<String, dynamic>> teachers = [];
  
  // Define subjects that teachers can teach
  const subjectGroups = [
    ['Mathematics', 'Calculus', 'Algebra'],
    ['Physics', 'Mechanics', 'Thermodynamics'],
    ['Chemistry', 'Organic Chemistry', 'Inorganic Chemistry'],
    ['Computer Science', 'Programming', 'Database Systems'],
    ['English', 'Literature', 'Writing'],
    ['History', 'World History', 'Modern History'],
    ['Biology', 'Cell Biology', 'Genetics'],
    ['Economics', 'Microeconomics', 'Macroeconomics'],
  ];
  
  const departments = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Computer Science',
    'Languages',
    'History',
    'Biology',
    'Economics',
  ];

  for (int i = 0; i < NUM_TEACHERS; i++) {
    final teacherId = ObjectId();
    final departmentIndex = i % departments.length;
    teachers.add({
      '_id': teacherId,
      'firstName': 'Teacher${i + 1}',
      'lastName': 'Last${i + 1}',
      'email': 'teacher${i + 1}@university.com',
      'username': 'teacher${i + 1}',
      'password': '12345678',
      'department': departments[departmentIndex],
      'subjects': subjectGroups[departmentIndex],
      'createdExams': <ObjectId>[],
      'role': 'teacher',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
  }

  return teachers;
}

// Generate classes (subjects) - each class has a subject and teacher
// Note: Some teachers may not be assigned to any class
List<Map<String, dynamic>> _generateClasses(List<Map<String, dynamic>> teachers) {
  final List<Map<String, dynamic>> classes = [];
  
  // Define class subjects (university-style course names)
  final classSubjects = [
    'Mathematics 101',
    'Mathematics 201',
    'Physics 101',
    'Physics 201',
    'Chemistry 101',
    'Computer Science 101',
    'English 101',
    'History 101',
    'Biology 101',
    'Economics 101',
  ];
  
  // Track which teachers have been assigned (to ensure some teachers don't teach)
  final assignedTeacherIds = <ObjectId>{};
  
  // Assign teachers to classes based on their subjects
  // Only assign NUM_CLASSES teachers (some will remain unassigned)
  for (int i = 0; i < NUM_CLASSES && i < classSubjects.length; i++) {
    final className = classSubjects[i];
    final subject = className.split(' ')[0]; // Extract base subject
    
    // Find a teacher who teaches this subject and hasn't been assigned yet
    Map<String, dynamic>? assignedTeacher;
    for (final teacher in teachers) {
      final teacherId = teacher['_id'] as ObjectId;
      if (assignedTeacherIds.contains(teacherId)) continue; // Skip already assigned
      
      final teacherSubjects = teacher['subjects'] as List<String>;
      if (teacherSubjects.any((s) => s.toLowerCase().contains(subject.toLowerCase()))) {
        assignedTeacher = teacher;
        assignedTeacherIds.add(teacherId);
        break;
      }
    }
    
    // If no matching teacher found, find any unassigned teacher
    if (assignedTeacher == null) {
      for (final teacher in teachers) {
        final teacherId = teacher['_id'] as ObjectId;
        if (!assignedTeacherIds.contains(teacherId)) {
          assignedTeacher = teacher;
          assignedTeacherIds.add(teacherId);
          break;
        }
      }
    }
    
    // If still no teacher, assign randomly (shouldn't happen with 10 teachers and 10 classes)
    if (assignedTeacher == null) {
      assignedTeacher = teachers[_random.nextInt(teachers.length)];
    }
    
    classes.add({
      'className': className,
      'subject': subject,
      'teacherId': assignedTeacher['_id'] as ObjectId,
      'teacherName': '${assignedTeacher['firstName']} ${assignedTeacher['lastName']}',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
  }
  
  return classes;
}

// Generate students
List<Map<String, dynamic>> _generateStudents() {
  final List<Map<String, dynamic>> students = [];
  
  for (int i = 0; i < NUM_STUDENTS; i++) {
    final studentId = _generateStudentId();
    
    students.add({
      '_id': ObjectId(),
      'studentId': studentId,
      'rollNumber': studentId,
      'firstName': 'Student${i + 1}',
      'lastName': 'Last${i + 1}',
      'email': 'student${i + 1}@university.com',
      'password': '12345678',
      'phoneNumber': '09${_random.nextInt(100000000).toString().padLeft(8, '0')}',
      'address': 'Address ${i + 1}',
      'assignedExams': <ObjectId>[], // Will be populated later
      'enrolledClasses': <String>[], // Will be populated later
      'role': 'student',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
  }
  
  return students;
}

// Assign students to classes (30-40 students per class)
// Each student can be enrolled in 2-4 different classes
Map<String, List<ObjectId>> _assignStudentsToClasses(
  List<Map<String, dynamic>> students,
  List<Map<String, dynamic>> classes,
) {
  final Map<String, List<ObjectId>> studentClassAssignments = {};
  
  // Initialize class assignments
  for (final classData in classes) {
    studentClassAssignments[classData['className'] as String] = [];
  }
  
  // Assign each student to 2-4 random classes
  for (final student in students) {
    final numClasses = STUDENT_CLASSES_MIN + 
        _random.nextInt(STUDENT_CLASSES_MAX - STUDENT_CLASSES_MIN + 1);
    
    // Shuffle classes and pick random ones
    final shuffledClasses = List<Map<String, dynamic>>.from(classes);
    shuffledClasses.shuffle(_random);
    
    final studentObjId = student['_id'] as ObjectId;
    final enrolledClasses = student['enrolledClasses'] as List<String>;
    
    for (int i = 0; i < numClasses && i < shuffledClasses.length; i++) {
      final classData = shuffledClasses[i];
      final className = classData['className'] as String;
      
      // Add student to class
      studentClassAssignments[className]!.add(studentObjId);
      enrolledClasses.add(className);
    }
  }
  
  return studentClassAssignments;
}

// Create classes collection with numStudent, studentList, and teacher
List<Map<String, dynamic>> _createClassesCollection(
  List<Map<String, dynamic>> classes,
  Map<String, List<ObjectId>> studentClassAssignments,
) {
  final List<Map<String, dynamic>> classesData = [];
  
  for (final classData in classes) {
    final className = classData['className'] as String;
    final studentList = studentClassAssignments[className] ?? [];
    final numStudent = studentList.length;
    final teacherId = classData['teacherId'] as ObjectId;
    final teacherName = classData['teacherName'] as String;
    final subject = classData['subject'] as String;
    
    classesData.add({
      '_id': ObjectId(),
      'className': className,
      'subject': subject,
      'numStudent': numStudent,
      'studentList': studentList,
      'teacher': teacherId,
      'teacherName': teacherName,
      'createdAt': classData['createdAt'] as DateTime,
      'updatedAt': DateTime.now(),
    });
  }
  
  return classesData;
}

// Generate question bank (standalone questions not tied to specific exams)
List<Map<String, dynamic>> _generateQuestionBank(List<Map<String, dynamic>> teachers) {
  final List<Map<String, dynamic>> questions = [];
  const difficulties = ['easy', 'medium', 'hard'];
  const questionTypes = ['multiple_choice', 'true_false', 'short_answer'];
  
  // All possible subjects
  final allSubjects = <String>{};
  for (final teacher in teachers) {
    final teacherSubjects = teacher['subjects'] as List<String>;
    allSubjects.addAll(teacherSubjects);
  }
  
  int questionIndex = 0;
  
  for (int i = 0; i < QUESTIONS_IN_DATABANK; i++) {
    final questionId = ObjectId();
    final subject = allSubjects.elementAt(_random.nextInt(allSubjects.length));
    final teacher = teachers[_random.nextInt(teachers.length)];
    final teacherId = teacher['_id'] as ObjectId;
    
    questions.add({
      '_id': questionId,
      'questionText': 'Question Bank Question ${questionIndex + 1}: What is the answer?',
      'type': questionTypes[_random.nextInt(questionTypes.length)],
      'subject': subject,
      'topic': 'Topic ${_random.nextInt(10) + 1}',
      'difficulty': difficulties[_random.nextInt(difficulties.length)],
      'points': 5 + _random.nextInt(15), // 5-20 points
      'options': ['Option A', 'Option B', 'Option C', 'Option D'],
      'correctAnswer': 'Option A',
      'correctOptionIndex': 0,
      'examId': null, // Not tied to any specific exam
      'createdBy': teacherId,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'isInBank': true, // Mark as question bank question
    });
    questionIndex++;
  }
  
  return questions;
}

// Generate exams and questions for classes
Map<String, dynamic> _generateExamsForClasses(
  List<Map<String, dynamic>> classes,
  List<Map<String, dynamic>> teachers,
  List<Map<String, dynamic>> questionBank,
) {
  final List<Map<String, dynamic>> exams = [];
  final List<Map<String, dynamic>> questions = [];
  const examTypes = ['Midterm', 'Final', 'Quiz'];
  const difficulties = ['easy', 'medium', 'hard'];
  
  int questionIndex = 0;

  for (final classData in classes) {
    final className = classData['className'] as String;
    final subject = classData['subject'] as String;
    final teacherId = classData['teacherId'] as ObjectId;
    
    // Find the teacher to update their createdExams
    final teacher = teachers.firstWhere(
      (t) => (t['_id'] as ObjectId) == teacherId,
      orElse: () => teachers[0],
    );

    // Generate exams for this class
    for (int j = 0; j < EXAMS_PER_CLASS; j++) {
      final examId = ObjectId();
      final examType = examTypes[j % examTypes.length];
      final examDate = DateTime.now().add(Duration(days: j * 30 + 1));

      // Generate questions for this exam
      final List<ObjectId> questionIds = [];
      for (int k = 0; k < QUESTIONS_PER_EXAM; k++) {
        final questionId = ObjectId();
        questionIds.add(questionId);

        final question = {
          '_id': questionId,
          'questionText': '$className - $examType - Question ${k + 1}: What is the answer?',
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
        'title': '$className - $examType Exam',
        'description': '$examType exam for $className',
        'subject': subject,
        'className': className, // Link exam to class
        'difficulty': 'medium',
        'examDate': examDate,
        'examTime': '09:00',
        'duration': 60,
        'maxStudents': STUDENTS_PER_CLASS_MAX,
        'questions': questionIds,
        'createdBy': teacherId,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'status': 'scheduled',
        'isDummy': false,
      };
      exams.add(exam);

      // Update teacher's createdExams
      (teacher['createdExams'] as List<ObjectId>).add(examId);
    }
  }

  return {'exams': exams, 'questions': questions};
}

// Assign students to exams based on their class enrollment
void _assignStudentsToExams(
  List<Map<String, dynamic>> students,
  List<Map<String, dynamic>> exams,
  Map<String, List<ObjectId>> studentClassAssignments,
) {
  // Create a map of className -> examIds
  final Map<String, List<ObjectId>> classExams = {};
  for (final exam in exams) {
    final className = exam['className'] as String?;
    if (className != null) {
      classExams.putIfAbsent(className, () => []).add(exam['_id'] as ObjectId);
    }
  }
  
  // Assign exams to students based on their enrolled classes
  for (final student in students) {
    final enrolledClasses = student['enrolledClasses'] as List<String>;
    final assignedExams = <ObjectId>[];
    
    for (final className in enrolledClasses) {
      final examIds = classExams[className] ?? [];
      assignedExams.addAll(examIds);
    }
    
    student['assignedExams'] = assignedExams;
  }
}

// Generate exam results for students
List<Map<String, dynamic>> _generateExamResults(
  List<Map<String, dynamic>> students,
  List<Map<String, dynamic>> exams,
  Map<String, List<ObjectId>> studentClassAssignments,
) {
  final List<Map<String, dynamic>> examResults = [];
  
  // Create a map of className -> studentIds
  final Map<String, List<ObjectId>> classStudents = {};
  for (final entry in studentClassAssignments.entries) {
    classStudents[entry.key] = entry.value;
  }
  
  // Generate results for past exams (exams that have already occurred)
  final now = DateTime.now();
  
  for (final exam in exams) {
    final examId = exam['_id'] as ObjectId;
    final examDate = exam['examDate'] as DateTime;
    final className = exam['className'] as String?;
    
    // Only generate results for exams that have passed
    if (examDate.isBefore(now) && className != null) {
      final studentIds = classStudents[className] ?? [];
      
      // Generate results for 60-90% of students (some may not have taken it)
      final participationRate = 0.6 + _random.nextDouble() * 0.3;
      final numParticipants = (studentIds.length * participationRate).round();
      
      final shuffledStudents = List<ObjectId>.from(studentIds);
      shuffledStudents.shuffle(_random);
      
      for (int i = 0; i < numParticipants && i < shuffledStudents.length; i++) {
        final studentId = shuffledStudents[i];
        
        // Generate a random score (0-100)
        final rawScore = 40 + _random.nextDouble() * 60; // Scores between 40-100
        final percentageScore = rawScore.round();
        final totalPoints = exam['questions'] != null 
            ? (exam['questions'] as List).length * 10 
            : 50;
        final obtainedPoints = (totalPoints * rawScore / 100).round();
        
        examResults.add({
          '_id': ObjectId(),
          'examId': examId,
          'studentId': studentId,
          'className': className,
          'score': obtainedPoints,
          'totalScore': totalPoints,
          'percentageScore': percentageScore,
          'answers': {}, // Empty answers for now
          'submittedAt': examDate.add(Duration(minutes: 30 + _random.nextInt(30))),
          'startedAt': examDate,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }
    }
  }
  
  return examResults;
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
      'email': 'admin$i@university.com',
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

// Generate a student ID (format: 2021 + 4-digit number, e.g., 20210001, 20210002)
String _generateStudentId() {
  final id = _studentIdCounter++;
  return '2021${id.toString().padLeft(4, '0')}';
}

