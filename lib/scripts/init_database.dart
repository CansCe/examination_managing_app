import 'package:mongo_dart/mongo_dart.dart';
import '../services/mongodb_service.dart';
import '../utils/mock_data_generator.dart';

Future<void> main() async {
  try {
    print('Starting database initialization...');
    
    // Initialize database connection
    await MongoDBService.init();
    print('Database connection established');

    // Generate mock data
    final mockData = await MockDataGenerator.generateBatch();
    print('\nGenerated mock data:');
    print('Teachers: ${mockData['teachers']?.length ?? 0}');
    print('Students: ${mockData['students']?.length ?? 0}');
    print('Exams: ${mockData['exams']?.length ?? 0}');
    print('Questions: ${mockData['questions']?.length ?? 0}');

    // Insert mock data for each collection
    print('\nInserting mock data...');
    
    // Clear existing data
    final db = await MongoDBService.getDatabase();
    await db.drop();
    print('Cleared existing database');

    // Create users collection and insert user records
    await db.createCollection('users');
    final usersCollection = db.collection('users');

    // Insert teacher users
    for (var teacher in mockData['teachers']!) {
      await usersCollection.insert({
        '_id': teacher['_id'],
        'username': teacher['username'],
        'email': teacher['email'],
        'password': teacher['password'],
        'fullName': '${teacher['firstName']} ${teacher['lastName']}',
        'role': 'teacher',
      });
    }

    // Insert student users
    for (var student in mockData['students']!) {
      await usersCollection.insert({
        '_id': student['_id'],
        'studentId': student['studentId'],
        'email': student['email'],
        'password': student['password'],
        'fullName': '${student['firstName']} ${student['lastName']}',
        'role': 'student',
      });
    }

    // Create and populate questions collection first
    await db.createCollection('questions');
    final questionsCollection = db.collection('questions');
    
    // Insert all questions and store their IDs
    final insertedQuestionIds = <ObjectId>[];
    for (var question in mockData['questions']!) {
      final result = await questionsCollection.insert(question);
      if (result['ok'] == 1.0) { // Check for successful insertion using the 'ok' field
        insertedQuestionIds.add(question['_id'] as ObjectId);
      }
    }
    print('Inserted ${insertedQuestionIds.length} questions');
    print('First few question IDs: ${insertedQuestionIds.take(3)}');

    // Create and populate exams collection
    await db.createCollection('exams');
    final examsCollection = db.collection('exams');
    
    // Insert all exams with their associated question IDs
    for (var exam in mockData['exams']!) {
      // Get questions for this exam
      final examQuestions = await questionsCollection
          .find({'examId': exam['_id']})
          .toList();
      
      // Update the exam with the correct question IDs
      exam['questions'] = examQuestions.map((q) => q['_id']).toList();
      
      await examsCollection.insert(exam);
    }
    print('Inserted ${mockData['exams']!.length} exams');

    // Create and populate teachers collection
    await db.createCollection('teachers');
    final teachersCollection = db.collection('teachers');
    
    // Insert all teachers
    for (var teacher in mockData['teachers']!) {
      await teachersCollection.insert(teacher);
    }
    print('Inserted ${mockData['teachers']!.length} teachers');

    // Create and populate students collection
    await db.createCollection('students');
    final studentsCollection = db.collection('students');
    
    // Insert all students
    for (var student in mockData['students']!) {
      await studentsCollection.insert(student);
    }
    print('Inserted ${mockData['students']!.length} students');

    // Verify data insertion
    print('\nVerifying data insertion...');
    final users = await usersCollection.find().toList();
    final teachers = await teachersCollection.find().toList();
    final students = await studentsCollection.find().toList();
    final exams = await examsCollection.find().toList();
    final questions = await questionsCollection.find().toList();

    print('\nDatabase contents:');
    print('Users: ${users.length}');
    print('Teachers: ${teachers.length}');
    print('Students: ${students.length}');
    print('Exams: ${exams.length}');
    print('Questions: ${questions.length}');

    // Print sample data
    if (exams.isNotEmpty) {
      print('\nSample exam:');
      print(exams.first);
      
      // Get questions for the first exam
      final questionIds = (exams.first['questions'] as List).map((id) => id as ObjectId).toList();
      print('\nLooking for questions with IDs:');
      for (var id in questionIds) {
        print('- $id');
      }

      // First verify these questions exist
      for (var id in questionIds) {
        final question = await questionsCollection.findOne({'_id': id});
        print('\nChecking question $id:');
        print(question != null ? 'Found' : 'Not found');
      }

      // Then try the $in query
      final examQuestions = await questionsCollection
          .find({'_id': {'\$in': questionIds}})
          .toList();
      
      print('\nQuestions for first exam:');
      print('Number of questions: ${examQuestions.length}');
      if (examQuestions.isNotEmpty) {
        print('Sample question:');
        print(examQuestions.first);
      }
    }

    print('\nDatabase initialization completed successfully!');
  } catch (e) {
    print('Error during database initialization: $e');
  } finally {
    // Close database connection
    await MongoDBService.close();
    print('\nDatabase connection closed');
  }
} 