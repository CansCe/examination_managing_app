import 'dart:math';
import 'package:mongo_dart/mongo_dart.dart';
import '../services/mongodb_service.dart';
import '../services/atlas_service.dart';
import '../config/database_config.dart';

class MockDataGenerator {
  static final _random = Random();

  // Configuration constants
  static const int _defaultTeacherCount = 5;
  static const int _defaultStudentCount = 20;
  static const int _defaultExamsPerTeacher = 3;
  static const int _defaultQuestionsPerExam = 5;

  // Data templates
  static const List<String> _departments = [
    'Science',
    'Mathematics',
    'Humanities',
    'Computer Science',
    'Arts',
    'Physical Education',
    'Social Studies',
    'Languages',
    'Business',
    'Engineering'
  ];
  static const List<List<String>> _departmentSubjects = [
    ['Physics', 'Chemistry'],
    ['Algebra', 'Calculus'],
    ['Programming', 'Database'],
  ];
  static const List<String> _examTypes = ['Midterm', 'Final', 'Quiz'];
  static const List<String> _difficulties = ['easy', 'medium', 'hard'];
  static const List<String> _questionTypes = ['multiple_choice', 'true_false', 'short_answer'];

  // Generate a complete batch of mock data
  static Future<Map<String, List<Map<String, dynamic>>>> generateBatch({bool uploadToMongoDB = true}) async {
    // Generate teachers first
    final teachers = _generateTeachers();
    
    // Generate exams and their associated questions using the teachers
    final examGenerationResult = _generateExams(teachers);
    final exams = examGenerationResult['exams']!;
    final questions = examGenerationResult['questions']!;
    
    // Generate students, assigning them to generated exams
    final students = _generateStudents(exams);
    
    // Generate admin users
    final admins = _generateAdmins();

    final mockData = {
      'teachers': teachers,
      'students': students,
      'exams': exams,
      'questions': questions,
      'admins': admins,
    };

    // Upload to MongoDB if requested
    if (uploadToMongoDB) {
      try {
        print('\n=== Starting MongoDB Upload Process ===');
        
        // Ensure AtlasService is initialized
        print('Initializing MongoDB connection...');
        await AtlasService.init();
        print('✓ Connected to MongoDB Atlas');
        
        print('\n⚠ DROPPING ENTIRE DATABASE AND REPLACING WITH NEW MOCK DATA...');
        print('⚠ This will delete ALL existing data in the database!');
        
        // Drop the entire database
        await AtlasService.dropDatabase();
        print('✓ Database dropped and recreated');
        
        print('\nUploading generated mock data to MongoDB...');
        print('Database: ${DatabaseConfig.databaseName}');
        
        // Upload teachers
        if (teachers.isNotEmpty) {
          print('Uploading ${teachers.length} teachers...');
          final teacherIds = await AtlasService.uploadMany(DatabaseConfig.teachersCollection, teachers);
          print('✓ Uploaded ${teachers.length} teachers (${teacherIds.length} IDs returned)');
        } else {
          print('⚠ No teachers to upload');
        }
        
        // Upload students
        if (students.isNotEmpty) {
          print('Uploading ${students.length} students...');
          final studentIds = await AtlasService.uploadMany(DatabaseConfig.studentsCollection, students);
          print('✓ Uploaded ${students.length} students (${studentIds.length} IDs returned)');
        } else {
          print('⚠ No students to upload');
        }
        
        // Upload exams
        if (exams.isNotEmpty) {
          print('Uploading ${exams.length} exams...');
          final examIds = await AtlasService.uploadMany(DatabaseConfig.examsCollection, exams);
          print('✓ Uploaded ${exams.length} exams (${examIds.length} IDs returned)');
        } else {
          print('⚠ No exams to upload');
        }
        
        // Upload questions
        if (questions.isNotEmpty) {
          print('Uploading ${questions.length} questions...');
          final questionIds = await AtlasService.uploadMany(DatabaseConfig.questionsCollection, questions);
          print('✓ Uploaded ${questions.length} questions (${questionIds.length} IDs returned)');
        } else {
          print('⚠ No questions to upload');
        }
        
        // Upload admins to users collection (only remove admin users, not all users)
        if (admins.isNotEmpty) {
          print('Processing ${admins.length} admin users...');
          // Delete existing admin users before inserting new ones
          try {
            final deletedCount = await AtlasService.deleteDocuments(
              DatabaseConfig.usersCollection,
              {'role': 'admin'},
            );
            print('✓ Cleared $deletedCount existing admin users');
          } catch (e) {
            print('⚠ Warning: Could not clear existing admin users: $e');
            // Continue anyway
          }
          
          print('Uploading ${admins.length} admin users...');
          final adminIds = await AtlasService.uploadMany(DatabaseConfig.usersCollection, admins);
          print('✓ Uploaded ${admins.length} admin users (${adminIds.length} IDs returned)');
        } else {
          print('⚠ No admins to upload');
        }
        
        print('\n=== Upload Summary ===');
        print('✓ Teachers: ${teachers.length}');
        print('✓ Students: ${students.length}');
        print('✓ Exams: ${exams.length}');
        print('✓ Questions: ${questions.length}');
        print('✓ Admins: ${admins.length}');
        print('\n✓ All mock data uploaded to MongoDB successfully!');
        print('=======================================\n');
      } catch (e, stackTrace) {
        print('\n❌ ERROR: Failed to upload mock data to MongoDB!');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        print('\n⚠ Warning: Mock data was generated but not uploaded.');
        print('You can try uploading it manually later.\n');
        rethrow; // Re-throw so caller knows upload failed
      }
    }

    return mockData;
  }

  // Generate teachers
  static List<Map<String, dynamic>> _generateTeachers() {
    final List<Map<String, dynamic>> teachers = [];

    for (int i = 0; i < _defaultTeacherCount; i++) {
      final departmentIndex = i % _departments.length;
      final teacherId = ObjectId();
      final teacher = {
        '_id': teacherId,
        'firstName': 'Teacher${i + 1}',
        'lastName': 'Last${i + 1}',
        'email': 'teacher${i + 1}@school.com',
        'username': 'teacher${i + 1}',
        'password': '12345678',
        'department': _departments[departmentIndex],
        'subjects': _departmentSubjects[departmentIndex % _departmentSubjects.length],
        'createdExams': <ObjectId>[],
        'role': 'teacher',
      };
      teachers.add(teacher);
    }

    return teachers;
  }

  // Generate students
  static List<Map<String, dynamic>> _generateStudents(List<Map<String, dynamic>> exams) {
    final List<Map<String, dynamic>> students = [];
    final classes = List.generate(10, (i) => 'Class ${i + 1}');

    // Extract exam ObjectIds for assignment
    final List<ObjectId> allExamIds = exams.map((exam) => exam['_id'] as ObjectId).toList();

    for (int i = 0; i < _defaultStudentCount; i++) {
      final studentId = '${2024}${(i + 1).toString().padLeft(4, '0')}';
      
      // Assign a random subset of exams to each student
      final List<ObjectId> assignedExams = [];
      
      if (allExamIds.isNotEmpty) { // Only proceed if there are exams to assign
        final numExamsToAssign = _random.nextInt(3) + 1; // Assign 1 to 3 exams
        for (int j = 0; j < numExamsToAssign; j++) {
          assignedExams.add(allExamIds[_random.nextInt(allExamIds.length)]);
        }
      }

      final student = {
        '_id': ObjectId(),
        'studentId': studentId,
        'firstName': 'Student${i + 1}',
        'lastName': 'Last${i + 1}',
        'email': 'student${i + 1}@example.com',
        'password': '12345678',
        'class': classes[i % classes.length],
        'subjects': ['Mathematics', 'Physics', 'Chemistry'],
        'assignedExams': assignedExams,
        'role': 'student',
      };
      students.add(student);
    }

    return students;
  }

  // Generate admin users
  static List<Map<String, dynamic>> _generateAdmins() {
    final List<Map<String, dynamic>> admins = [];
    
    // Create 2 admin users
    for (int i = 1; i <= 2; i++) {
      final adminId = ObjectId();
      final admin = {
        '_id': adminId,
        'firstName': 'Admin${i}',
        'lastName': 'Support',
        'email': 'admin${i}@school.com',
        'username': 'admin${i}',
        'password': '12345678', // Default password
        'fullName': 'Admin${i} Support',
        'role': 'admin',
        'isActive': true,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };
      admins.add(admin);
    }
    
    return admins;
  }

  static List<Map<String, dynamic>> _generateQuestions(List<Map<String, dynamic>> exams) {
    final questions = <Map<String, dynamic>>[];
    final random = Random();
    final subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];
    final difficulties = ['easy', 'medium', 'hard'];

    // Sample questions for each subject
    final sampleQuestions = {
      'Mathematics': [
        {
          'text': 'What is the derivative of f(x) = x²?',
          'options': ['2x', 'x²', '2', 'x'],
          'correctAnswer': '2x'
        },
        {
          'text': 'Solve the equation: 2x + 5 = 13',
          'options': ['x = 4', 'x = 3', 'x = 5', 'x = 6'],
          'correctAnswer': 'x = 4'
        },
        {
          'text': 'What is the value of π (pi) to two decimal places?',
          'options': ['3.14', '3.16', '3.12', '3.18'],
          'correctAnswer': '3.14'
        }
      ],
      'Physics': [
        {
          'text': 'What is the SI unit of force?',
          'options': ['Newton', 'Joule', 'Watt', 'Pascal'],
          'correctAnswer': 'Newton'
        },
        {
          'text': 'What is the formula for kinetic energy?',
          'options': ['½mv²', 'mgh', 'Fd', 'ma'],
          'correctAnswer': '½mv²'
        },
        {
          'text': 'What is the speed of light in vacuum?',
          'options': ['3 × 10⁸ m/s', '2 × 10⁸ m/s', '4 × 10⁸ m/s', '1 × 10⁸ m/s'],
          'correctAnswer': '3 × 10⁸ m/s'
        }
      ],
      'Chemistry': [
        {
          'text': 'What is the chemical symbol for gold?',
          'options': ['Au', 'Ag', 'Fe', 'Cu'],
          'correctAnswer': 'Au'
        },
        {
          'text': 'What is the pH of a neutral solution?',
          'options': ['7', '0', '14', '1'],
          'correctAnswer': '7'
        },
        {
          'text': 'What is the formula for water?',
          'options': ['H₂O', 'CO₂', 'O₂', 'H₂'],
          'correctAnswer': 'H₂O'
        }
      ],
      'Biology': [
        {
          'text': 'What is the powerhouse of the cell?',
          'options': ['Mitochondria', 'Nucleus', 'Ribosome', 'Golgi apparatus'],
          'correctAnswer': 'Mitochondria'
        },
        {
          'text': 'What is the process by which plants make their food?',
          'options': ['Photosynthesis', 'Respiration', 'Digestion', 'Fermentation'],
          'correctAnswer': 'Photosynthesis'
        },
        {
          'text': 'What is the largest organ in the human body?',
          'options': ['Skin', 'Liver', 'Heart', 'Brain'],
          'correctAnswer': 'Skin'
        }
      ],
      'English': [
        {
          'text': 'Which of the following is a proper noun?',
          'options': ['London', 'city', 'building', 'river'],
          'correctAnswer': 'London'
        },
        {
          'text': 'What is the past tense of "write"?',
          'options': ['wrote', 'written', 'writed', 'writing'],
          'correctAnswer': 'wrote'
        },
        {
          'text': 'Which word is an antonym of "happy"?',
          'options': ['sad', 'joyful', 'cheerful', 'glad'],
          'correctAnswer': 'sad'
        }
      ]
    };

    for (var exam in exams) {
      final subject = exam['subject'] as String;
      final examId = exam['_id'];
      final questionCount = _random.nextInt(3) + 3; // 3-5 questions per exam

      for (var i = 0; i < questionCount; i++) {
        final subjectQuestions = sampleQuestions[subject] ?? sampleQuestions['Mathematics']!;
        final questionTemplate = subjectQuestions[i % subjectQuestions.length];
        
        final question = {
          '_id': ObjectId(),
          'text': questionTemplate['text'],
          'type': 'multiple_choice',
          'subject': subject,
          'difficulty': _difficulties[_random.nextInt(_difficulties.length)],
          'points': _random.nextInt(3) + 1, // 1-3 points per question
          'examId': examId,
          'options': questionTemplate['options'],
          'correctAnswer': questionTemplate['correctAnswer'],
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        };
        questions.add(question);
      }
    }
    return questions;
  }
  // Generate exams for teachers
  static Map<String, List<Map<String, dynamic>>> _generateExams(List<Map<String, dynamic>> teachers) {
    final List<Map<String, dynamic>> exams = [];
    final List<Map<String, dynamic>> questions = []; // To collect all questions generated here

    for (final teacher in teachers) {
      final teacherId = teacher['_id'] as ObjectId;
      final teacherSubjects = List<String>.from(teacher['subjects'] as List);

      for (int i = 0; i < _defaultExamsPerTeacher; i++) {
        final examId = ObjectId();
        final subjectIndex = _random.nextInt(teacherSubjects.length);
        final subject = teacherSubjects[subjectIndex];
        final examType = _examTypes[_random.nextInt(_examTypes.length)];
        final difficulty = _difficulties[_random.nextInt(_difficulties.length)];

        final List<ObjectId> questionIdsForThisExam = []; // To store ObjectIds for the current exam

        // Get sample questions for the subject
        final subjectQuestions = _getSampleQuestionsForSubject(subject);

        // Randomly select questions for this exam
        for (int j = 0; j < _defaultQuestionsPerExam; j++) {
          final questionTemplate = subjectQuestions[j % subjectQuestions.length];
          
          final questionId = ObjectId();
          questionIdsForThisExam.add(questionId); // Add the ObjectId to the list for THIS exam

          final question = {
            '_id': questionId,
            'text': questionTemplate['text'],
            'type': 'multiple_choice',
            'subject': subject,
            'difficulty': _difficulties[_random.nextInt(_difficulties.length)],
            'points': _random.nextInt(3) + 1, // 1-3 points per question
            'examId': examId, // Link question to this exam's ID
            'options': questionTemplate['options'],
            'correctAnswer': questionTemplate['correctAnswer'],
            'correctOptionIndex': questionTemplate['options'] != null && questionTemplate['correctAnswer'] != null
                ? questionTemplate['options'].indexOf(questionTemplate['correctAnswer'])
                : null,
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          };
          questions.add(question); // Add to the global questions list
        }

        // Create the exam map and include the generated question ObjectIds
        final exam = {
          '_id': examId,
          'title': '$subject $examType ${i + 1}',
          'description': 'This is an $difficulty $examType exam for $subject',
          'subject': subject,
          'difficulty': difficulty,
          // Generate random start time: date within 1 month (0-30 days), random time
          'examDate': DateTime.now().add(Duration(days: _random.nextInt(31))), // 0-30 days (about 1 month)
          'examTime': '${_random.nextInt(24).toString().padLeft(2, '0')}:${_random.nextInt(60).toString().padLeft(2, '0')}', // Random time
          'duration': _random.nextInt(60) + 30, // 30-90 minutes
          'maxStudents': _random.nextInt(50) + 20, // 20-70 students
          'questions': questionIdsForThisExam, // Assign the list of question ObjectIds
          'createdBy': teacherId,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'status': 'scheduled',
        };
        exams.add(exam);
      }
    }

    // After all exams are created, update teachers' createdExams lists
    for (final exam in exams) {
      final createdBy = exam['createdBy'] as ObjectId;
      final examId = exam['_id'] as ObjectId;
      
      // Find the teacher who created this exam
      final teacher = teachers.firstWhere(
        (t) => t['_id'] == createdBy,
        orElse: () => throw Exception('Teacher not found for exam ${exam['title']}'),
      );
      
      // Add the exam ID to the teacher's createdExams list
      if (teacher['createdExams'] == null) {
        teacher['createdExams'] = <ObjectId>[];
      }
      (teacher['createdExams'] as List<ObjectId>).add(examId);
    }

    return {
      'exams': exams,
      'questions': questions,
    };
  }

  // Helper method to get sample questions for a subject
  static List<Map<String, dynamic>> _getSampleQuestionsForSubject(String subject) {
    final sampleQuestions = {
      'Mathematics': [
        {
          'text': 'What is the derivative of f(x) = x²?',
          'options': ['2x', 'x²', '2', 'x'],
          'correctAnswer': '2x'
        },
        {
          'text': 'Solve the equation: 2x + 5 = 13',
          'options': ['x = 4', 'x = 3', 'x = 5', 'x = 6'],
          'correctAnswer': 'x = 4'
        },
        {
          'text': 'What is the value of π (pi) to two decimal places?',
          'options': ['3.14', '3.16', '3.12', '3.18'],
          'correctAnswer': '3.14'
        }
      ],
      'Physics': [
        {
          'text': 'What is the SI unit of force?',
          'options': ['Newton', 'Joule', 'Watt', 'Pascal'],
          'correctAnswer': 'Newton'
        },
        {
          'text': 'What is the formula for kinetic energy?',
          'options': ['½mv²', 'mgh', 'Fd', 'ma'],
          'correctAnswer': '½mv²'
        },
        {
          'text': 'What is the speed of light in vacuum?',
          'options': ['3 × 10⁸ m/s', '2 × 10⁸ m/s', '4 × 10⁸ m/s', '1 × 10⁸ m/s'],
          'correctAnswer': '3 × 10⁸ m/s'
        }
      ],
      'Chemistry': [
        {
          'text': 'What is the chemical symbol for gold?',
          'options': ['Au', 'Ag', 'Fe', 'Cu'],
          'correctAnswer': 'Au'
        },
        {
          'text': 'What is the pH of a neutral solution?',
          'options': ['7', '0', '14', '1'],
          'correctAnswer': '7'
        },
        {
          'text': 'What is the formula for water?',
          'options': ['H₂O', 'CO₂', 'O₂', 'H₂'],
          'correctAnswer': 'H₂O'
        }
      ]
    };

    return sampleQuestions[subject] ?? sampleQuestions['Mathematics']!; // Fallback to Mathematics questions
  }

  // Add this field at the class level
  static final List<Map<String, dynamic>> _generatedQuestions = [];

  // Mock data for subjects
  static final List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English Literature',
    'History',
    'Geography',
    'Economics',
    'Psychology',
    'Art',
    'Music',
    'Physical Education',
    'Environmental Science',
    'Political Science'
  ];

  // Mock data for difficulty levels
  static final List<String> _difficultyLevels = [
    'Easy',
    'Medium',
    'Hard',
    'Advanced',
    'Expert'
  ];

  // Mock data for exam status
  static final List<String> _examStatuses = [
    'scheduled',
    'in_progress',
    'completed',
    'cancelled',
    'postponed'
  ];

  // Mock data for exam rooms
  static final List<String> _examRooms = [
    'Room 101',
    'Room 102',
    'Room 103',
    'Lab 1',
    'Lab 2',
    'Auditorium',
    'Computer Lab',
    'Library',
    'Conference Room',
    'Gymnasium'
  ];

  // Mock data for first names
  static final List<String> _firstNames = [
    'John', 'Jane', 'Michael', 'Sarah', 'David', 'Emma',
    'James', 'Emily', 'William', 'Olivia', 'Daniel', 'Sophia',
    'Matthew', 'Ava', 'Joseph', 'Isabella', 'Andrew', 'Mia',
    'Christopher', 'Charlotte', 'Joshua', 'Amelia', 'Ryan', 'Harper'
  ];

  // Mock data for last names
  static final List<String> _lastNames = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia',
    'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez',
    'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore',
    'Jackson', 'Martin', 'Lee', 'Thompson', 'White', 'Harris'
  ];

  // Mock data for cities
  static final List<String> _cities = [
    'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
    'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose',
    'Austin', 'Jacksonville', 'Fort Worth', 'Columbus', 'San Francisco'
  ];

  // Mock data for states
  static final List<String> _states = [
    'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'FL', 'OH', 'GA', 'NC',
    'MI', 'NJ', 'VA', 'WA', 'MA', 'TN', 'IN', 'MO', 'MD', 'CO'
  ];

  // Mock data for departments
  // static final List<String> _departments = [
  //   'Science',
  //   'Mathematics',
  //   'Humanities',
  //   'Computer Science',
  //   'Arts',
  //   'Physical Education',
  //   'Social Studies',
  //   'Languages',
  //   'Business',
  //   'Engineering'
  // ];

  // Mock data for qualifications
  static final List<String> _qualifications = [
    'B.Ed',
    'M.Ed',
    'PhD',
    'MA',
    'MS',
    'MBA',
    'BSc',
    'MSc',
    'BA',
    'MA'
  ];

  // Predefined subjects and their classes
  static final Map<String, List<String>> _subjectClasses = {
    'Mathematics': ['MATH101', 'MATH102', 'MATH201', 'MATH202'],
    'Physics': ['PHY101', 'PHY102', 'PHY201', 'PHY202'],
    'Chemistry': ['CHEM101', 'CHEM102', 'CHEM201', 'CHEM202'],
    'Computer Science': ['CS101', 'CS102', 'CS201', 'CS202'],
    'English': ['ENG101', 'ENG102', 'ENG201', 'ENG202'],
  };

  // Generate a single exam document
  static Map<String, dynamic> generateExamDocument() {
    final examId = ObjectId();
    final subject = _subjects[_random.nextInt(_subjects.length)];
    final examType = _examTypes[_random.nextInt(_examTypes.length)];
    final difficulty = _difficultyLevels[_random.nextInt(_difficultyLevels.length)];
    final status = _examStatuses[_random.nextInt(_examStatuses.length)];
    final room = _examRooms[_random.nextInt(_examRooms.length)];
    
    return {
      '_id': examId,
      'title': '$subject $examType',
      'description': 'This is a $difficulty $examType for $subject',
      'subject': subject,
      // Random start date within 1 month (0-30 days)
      'date': DateTime.now().add(Duration(days: _random.nextInt(31))).toIso8601String(), // 0-30 days (about 1 month)
      'duration': 60 + _random.nextInt(60), // 60-120 minutes
      'maxStudents': 30 + _random.nextInt(20), // 30-50 students
      'difficulty': difficulty,
      'status': status,
      'room': room,
      'createdBy': ObjectId(), // This will be updated with actual teacher ID
      'questions': [], // Will be populated with questions later
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // Generate a single student document
  static Map<String, dynamic> generateStudentDocument() {
    final studentId = ObjectId();
    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@student.edu';
    final city = _cities[_random.nextInt(_cities.length)];
    final state = _states[_random.nextInt(_states.length)];
    
    return {
      '_id': studentId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'rollNumber': 'STU${_random.nextInt(10000).toString().padLeft(5, '0')}',
      'class': ['10A', '10B', '11A', '11B', '12A', '12B'][_random.nextInt(6)],
      'enrollmentDate': DateTime.now().subtract(Duration(days: _random.nextInt(365))).toIso8601String(),
      'isActive': true,
      'contactNumber': '+1${_random.nextInt(900000000) + 1000000000}',
      'address': {
        'street': '${_random.nextInt(1000)} Main St',
        'city': city,
        'state': state,
        'zipCode': '${_random.nextInt(90000) + 10000}'
      },
      'dateOfBirth': DateTime.now().subtract(Duration(days: 365 * (15 + _random.nextInt(6)))).toIso8601String(),
      'gender': ['Male', 'Female', 'Other'][_random.nextInt(3)],
      'parentName': '${_firstNames[_random.nextInt(_firstNames.length)]} ${_lastNames[_random.nextInt(_lastNames.length)]}',
      'parentContact': '+1${_random.nextInt(900000000) + 1000000000}',
      'emergencyContact': '+1${_random.nextInt(900000000) + 1000000000}',
      'bloodGroup': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'][_random.nextInt(8)],
      'medicalConditions': _random.nextBool() ? ['None'] : ['Asthma', 'Diabetes', 'Allergies'][_random.nextInt(3)],
      'attendance': {
        'present': _random.nextInt(100),
        'absent': _random.nextInt(20),
        'late': _random.nextInt(10)
      },
      'grades': {
        'semester1': _random.nextInt(41) + 60, // 60-100
        'semester2': _random.nextInt(41) + 60,
        'semester3': _random.nextInt(41) + 60,
        'semester4': _random.nextInt(41) + 60
      },
      'role': 'student',
    };
  }

  // Generate a single teacher document
  static Map<String, dynamic> generateTeacherDocument() {
    final teacherId = ObjectId();
    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@school.edu';
    final department = _departments[_random.nextInt(_departments.length)];
    final qualification = _qualifications[_random.nextInt(_qualifications.length)];
    
    return {
      '_id': teacherId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'employeeId': 'TCH${_random.nextInt(10000).toString().padLeft(5, '0')}',
      'subjects': List.generate(
        _random.nextInt(3) + 1,
        (index) => _subjects[_random.nextInt(_subjects.length)]
      ).toSet().toList(),
      'qualification': qualification,
      'department': department,
      'joiningDate': DateTime.now().subtract(Duration(days: _random.nextInt(3650))).toIso8601String(),
      'isActive': true,
      'contactNumber': '+1${_random.nextInt(900000000) + 1000000000}',
      'address': {
        'street': '${_random.nextInt(1000)} Main St',
        'city': _cities[_random.nextInt(_cities.length)],
        'state': _states[_random.nextInt(_states.length)],
        'zipCode': '${_random.nextInt(90000) + 10000}'
      },
      'dateOfBirth': DateTime.now().subtract(Duration(days: 365 * (25 + _random.nextInt(20)))).toIso8601String(),
      'gender': ['Male', 'Female', 'Other'][_random.nextInt(3)],
      'experience': _random.nextInt(20) + 1, // 1-20 years
      'salary': 40000 + (_random.nextInt(41) * 1000), // $40,000 - $80,000
      'classes': List.generate(
        _random.nextInt(5) + 1,
        (index) => ['10A', '10B', '11A', '11B', '12A', '12B'][_random.nextInt(6)]
      ).toSet().toList(),
      'officeHours': {
        'start': '09:00',
        'end': '17:00',
        'days': ['Monday', 'Wednesday', 'Friday']
      },
      'specialization': List.generate(
        _random.nextInt(3) + 1,
        (index) => _subjects[_random.nextInt(_subjects.length)]
      ).toSet().toList(),
      'achievements': List.generate(
        _random.nextInt(4),
        (index) => [
          'Teacher of the Year',
          'Best Research Paper',
          'Excellence in Teaching',
          'Innovation Award'
        ][_random.nextInt(4)]
      ).toSet().toList(),
      'role': 'teacher',
    };
  }

  // Generate a student ID (8 digits)
  static String _generateStudentId() {
    return List.generate(8, (_) => _random.nextInt(10)).join();
  }

  // Generate a class with 25 students
  static List<Map<String, dynamic>> _generateClassStudents(String className) {
    return List.generate(25, (index) {
      final studentId = _generateStudentId();
      return {
        '_id': ObjectId(),
        'studentId': studentId,
        'firstName': 'Student${index + 1}',
        'lastName': 'Class$className',
        'email': 'student$studentId@example.com',
        'class': className,
        'rollNumber': (index + 1).toString().padLeft(2, '0'),
        'phoneNumber': '09${_random.nextInt(100000000).toString().padLeft(8, '0')}',
        'address': 'Address ${index + 1}',
        'password': '12345678', // Default password
        'role': 'student',
      };
    });
  }

  // Generate all students for all classes
  static List<Map<String, dynamic>> generateStudents() {
    List<Map<String, dynamic>> allStudents = [];
    _subjectClasses.forEach((subject, classes) {
      for (var className in classes) {
        allStudents.addAll(_generateClassStudents(className));
      }
    });
    return allStudents;
  }

  // Generate teachers with their subjects
  static List<Map<String, dynamic>> generateTeachers() {
    final List<Map<String, dynamic>> teachers = [];
    final departments = ['Science', 'Mathematics', 'Computer Science'];
    final subjects = [
      ['Physics', 'Chemistry'],
      ['Algebra', 'Calculus'],
      ['Programming', 'Database'],
    ];

    for (int i = 0; i < 5; i++) {
      final departmentIndex = i % departments.length;
      final teacherId = ObjectId();
      final teacher = {
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
      };
      teachers.add(teacher);
    }

    return teachers;
  }

  // Generate exams for each teacher
  static Future<List<Map<String, dynamic>>> generateExams() async {
    final List<Map<String, dynamic>> exams = [];
    final examTypes = ['Midterm', 'Final', 'Quiz'];
    final difficulties = ['easy', 'medium', 'hard'];
    final subjects = [
      ['Physics', 'Chemistry'],
      ['Algebra', 'Calculus'],
      ['Programming', 'Database'],
    ];
    final departments = ['Science', 'Mathematics', 'Computer Science'];

    // Generate 5 teachers first
    final teachers = List.generate(5, (i) {
      final departmentIndex = i % departments.length;
      final teacherId = ObjectId();
      return {
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
      };
    });

    // Generate 2-4 exams per teacher
    for (final teacher in teachers) {
      final teacherId = teacher['_id'] as ObjectId;
      final teacherSubjects = List<String>.from(teacher['subjects'] as List);

      final numExams = _random.nextInt(3) + 2;
      for (int i = 0; i < numExams; i++) {
        final examId = ObjectId();
        final subject = teacherSubjects[_random.nextInt(teacherSubjects.length)];
        final examType = examTypes[_random.nextInt(examTypes.length)];
        final difficulty = difficulties[_random.nextInt(difficulties.length)];

        final exam = {
          '_id': examId,
          'title': '$subject $examType ${i + 1}',
          'description': 'This is a $difficulty $examType exam for $subject',
          'subject': subject,
          // Random start date within 1 month (0-30 days)
          'date': DateTime.now().add(Duration(days: _random.nextInt(31))), // 0-30 days (about 1 month)
          'duration': 60 + _random.nextInt(60), // 60-120 minutes
          'maxStudents': 30 + _random.nextInt(20), // 30-50 students
          'difficulty': difficulty,
          'status': 'scheduled',
          'createdBy': teacherId,
          'questions': <ObjectId>[],
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'role': 'teacher',
        };
        exams.add(exam);
      }
    }

    return exams;
  }

  // Generate questions for each exam
  static Future<List<Map<String, dynamic>>> generateQuestions() async {
    final List<Map<String, dynamic>> questions = [];
    final questionTypes = ['multiple_choice', 'true_false', 'short_answer'];
    final difficulties = ['easy', 'medium', 'hard'];

    // Get teachers from the database
    final teachers =await MongoDBService.findTeachers();
    if (teachers.isEmpty) return questions;

    for (final teacher in teachers) {
      final teacherId = teacher.id;
      final teacherSubjects = List<String>.from(teacher.subjects);

      // Generate 5-10 questions per teacher
      final numQuestions = _random.nextInt(6) + 5;
      for (int i = 0; i < numQuestions; i++) {
        final subject = teacherSubjects[_random.nextInt(teacherSubjects.length)];
        final questionType = questionTypes[_random.nextInt(questionTypes.length)];
        final difficulty = difficulties[_random.nextInt(difficulties.length)];

        final question = {
          '_id': ObjectId(),
          'text': 'Sample question ${i + 1} for $subject',
          'type': questionType,
          'subject': subject,
          'difficulty': difficulty,
          'points': 5 + _random.nextInt(15), // 5-20 points
          'createdBy': teacherId,
          'options': questionType == 'multiple_choice' 
              ? ['Option A', 'Option B', 'Option C', 'Option D']
              : [],
          'correctAnswer': questionType == 'multiple_choice' 
              ? 'Option ${String.fromCharCode(65 + _random.nextInt(4))}'
              : questionType == 'true_false'
                  ? _random.nextBool()
                  : 'Sample answer',
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'role': 'teacher',
        };
        questions.add(question);
      }
    }

    return questions;
  }

  static Future<void> loadMockData() async {
    try {
      // Clear existing data
      await MongoDBService.clearCollections();
      
      // Generate and insert teachers
      final teachers = generateTeachers();
      await MongoDBService.insertTeachers(teachers);
      
      // Generate and insert questions for each teacher
      // for (final teacher in teachers) {
      //   final questions = generateQuestions();
      //   await MongoDBService.insertQuestions(await questions);
      // }
      
      // Generate and insert students
      final students = generateStudents();
      await MongoDBService.insertStudents(students);
      
      // Generate and insert exams
      final exams = await generateExams();
      await MongoDBService.insertExams(exams);
      
      print('Mock data loaded successfully');
    } catch (e) {
      print('Error loading mock data: $e');
    }
  }
} 