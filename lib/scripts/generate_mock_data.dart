import 'dart:io';
import '../services/mongodb_service.dart';
import '../utils/mock_data_export.dart';

int _parseArg(List<String> args, String name, int defaultValue) {
  final arg = args.firstWhere(
    (a) => a.startsWith('--$name='),
    orElse: () => '',
  );
  if (arg.isNotEmpty) {
    final value = int.tryParse(arg.split('=')[1]);
    if (value != null && value > 0) return value;
  }
  return defaultValue;
}

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    print('''\nUsage: dart run lib/scripts/generate_mock_data.dart [--students=N] [--teachers=N] [--exams=N]\n\nAll arguments are optional. Defaults: students=500, teachers=30, exams=100\n''');
    exit(0);
  }

  final studentCount = _parseArg(args, 'students', 500);
  final teacherCount = _parseArg(args, 'teachers', 30);
  final examCount = _parseArg(args, 'exams', 100);

  try {
    print('Starting mock data generation and export...\n');
    print('Counts: students=\u001b[32m$studentCount\u001b[0m, teachers=\u001b[32m$teacherCount\u001b[0m, exams=\u001b[32m$examCount\u001b[0m');

    // Initialize MongoDB connection
    print('Connecting to MongoDB...');
    await MongoDBService.init();

    // Export custom amounts
    print('\nGenerating and exporting custom mock data...');
    await MongoDBService.exportCustomMockData(
      examCount: examCount,
      studentCount: studentCount,
      teacherCount: teacherCount,
    );

    // Load mock data from JSON files and insert into MongoDB
    print('\nLoading mock data into MongoDB...');
    final mockData = await MockDataExport.loadMockData();
    print('DEBUG: Loaded mockData keys: ${mockData.keys}');
    print('DEBUG: Loaded mockData values types: ${mockData.values.map((v) => v.runtimeType).toList()}');
    print('DEBUG: Loaded mockData content: $mockData');

    await MongoDBService.insertTeachers(mockData['teachers']!);
    await MongoDBService.insertStudents(mockData['students']!);
    await MongoDBService.insertExams(mockData['exams']!);
    await MongoDBService.insertQuestions(mockData['questions']!);

    // Close MongoDB connection
    print('\nClosing MongoDB connection...');
    await MongoDBService.close();

    print('\nMock data generation and export completed successfully!');
  } catch (e) {
    print('\nError: $e');
    exit(1);
  }
} 