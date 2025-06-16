import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mongo_dart/mongo_dart.dart';
import 'mock_data_generator.dart';

class MockDataExport {
  static const String _mockDataDir = 'lib/database/mock_data';
  static const String _teachersFile = 'teachers.json';
  static const String _studentsFile = 'students.json';
  static const String _examsFile = 'exams.json';
  static const String _questionsFile = 'questions.json';

  // Clear existing mock data files
  static Future<void> clearMockDataFiles() async {
    final dir = Directory(_mockDataDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  // Convert ObjectId to string in a map
  static Map<String, dynamic> _convertObjectIdToString(Map<String, dynamic> data) {
    final Map<String, dynamic> result = {};
    
    data.forEach((key, value) {
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIdToString(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is DateTime) {
            return item.toIso8601String();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIdToString(item);
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

  // Convert string to ObjectId in a map
  static Map<String, dynamic> _convertStringToObjectId(Map<String, dynamic> data) {
    final Map<String, dynamic> result = {};
    
    data.forEach((key, value) {
      if (value is String) {
        if (key == '_id' || key.endsWith('Id')) {
          try {
            if (value.length == 24) {
              result[key] = ObjectId.fromHexString(value);
            } else {
              result[key] = value; // Keep as string if not valid ObjectId
            }
          } catch (e) {
            print('Error converting ID: $value');
            result[key] = value; // Keep as string if conversion fails
          }
        } else if (key == 'date' || key == 'createdAt' || key == 'updatedAt') {
          try {
            result[key] = DateTime.parse(value);
          } catch (e) {
            print('Error converting date: $value');
            result[key] = value; // Keep as string if conversion fails
          }
        } else {
          result[key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertStringToObjectId(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item == null) return null; // Handle null items explicitly

          if (item is String) {
            // Special handling for assignedExams list, where items are ObjectIds
            if (key == 'assignedExams') {
              try {
                return ObjectId.fromHexString(item);
              } catch (e) {
                print('Error converting assignedExam ID in list: $item');
                return item; // Keep as string if conversion fails
              }
            }
            
            // Original logic for other ID fields
            if (key == '_id' || key.endsWith('Id')) {
              try {
                if (item.length == 24) {
                  return ObjectId.fromHexString(item);
                }
              } catch (e) {
                print('Error converting list item ID: $item');
              }
            } else if (key == 'date' || key == 'createdAt' || key == 'updatedAt') {
              try {
                return DateTime.parse(item);
              } catch (e) {
                print('Error converting list item date: $item');
              }
            }
          } else if (item is Map<String, dynamic>) {
            return _convertStringToObjectId(item);
          }
          return item; // Filter out nulls
        }).where((item) => item != null).toList();
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

  // Export mock data to JSON files
  static Future<void> exportMockData() async {
    try {
      // Clear existing files
      await clearMockDataFiles();

      // Generate mock data
      final mockData = await MockDataGenerator.generateBatch();

      // Convert ObjectIds to strings before exporting
      final teachers = mockData['teachers']!.map((t) => _convertObjectIdToString(t)).toList();
      final students = mockData['students']!.map((s) => _convertObjectIdToString(s)).toList();
      final exams = mockData['exams']!.map((e) => _convertObjectIdToString(e)).toList();
      final questions = mockData['questions']!.map((q) => _convertObjectIdToString(q)).toList();

      // Create mock data directory if it doesn't exist
      final dir = Directory(_mockDataDir);
      if (!await dir.exists()) {
        await dir.create();
      }

      // Export each collection to its own file
      await _writeJsonFile(_teachersFile, teachers);
      await _writeJsonFile(_studentsFile, students);
      await _writeJsonFile(_examsFile, exams);
      await _writeJsonFile(_questionsFile, questions);

      print('Successfully exported mock data');
    } catch (e) {
      print('Error exporting mock data: $e');
      rethrow;
    }
  }

  // Load mock data from JSON files
  static Future<Map<String, List<Map<String, dynamic>>>> loadMockData() async {
    try {
      final teachers = await _readJsonFile(_teachersFile);
      final students = await _readJsonFile(_studentsFile);
      final exams = await _readJsonFile(_examsFile);
      final questions = await _readJsonFile(_questionsFile);

      // Convert string IDs back to ObjectIds
      final convertedTeachers = teachers.map((t) => _convertStringToObjectId(t)).toList();
      final convertedStudents = students.map((s) => _convertStringToObjectId(s)).toList();
      final convertedExams = exams.map((e) => _convertStringToObjectId(e)).toList();
      final convertedQuestions = questions.map((q) => _convertStringToObjectId(q)).toList();

      return {
        'teachers': convertedTeachers,
        'students': convertedStudents,
        'exams': convertedExams,
        'questions': convertedQuestions,
      };
    } catch (e) {
      print('Error loading mock data: $e');
      rethrow;
    }
  }

  // Helper method to write JSON file with pretty printing
  static Future<void> _writeJsonFile(String filename, List<Map<String, dynamic>> data) async {
    final file = File(path.join(_mockDataDir, filename));
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(prettyJson);
  }

  // Helper method to read JSON file
  static Future<List<Map<String, dynamic>>> _readJsonFile(String filename) async {
    final file = File(path.join(_mockDataDir, filename));
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    if (content.isEmpty) { // Handle empty file content
      return [];
    }
    final dynamic decodedContent = jsonDecode(content);
    if (decodedContent is List) {
      return decodedContent.cast<Map<String, dynamic>>();
    } else {
      print('Warning: Expected a List in $filename, but got ${decodedContent.runtimeType}');
      return [];
    }
  }
} 