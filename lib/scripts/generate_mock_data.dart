import 'dart:io';
import '../services/atlas_service.dart';
import '../utils/mock_data_generator.dart';

/// Standalone script to generate and upload mock data to MongoDB Atlas
/// 
/// Usage:
///   dart run lib/scripts/generate_mock_data.dart
/// 
/// This script will:
///   1. Connect to MongoDB Atlas
///   2. Drop the entire database
///   3. Generate fresh mock data
///   4. Upload all data to the cluster
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print('''
Mock Data Generator Script
==========================

This script generates mock data and uploads it to MongoDB Atlas.

Usage:
  dart run lib/scripts/generate_mock_data.dart

The script will:
  1. Connect to MongoDB Atlas (exam_management database)
  2. Drop the entire database (WARNING: This deletes ALL existing data!)
  3. Generate fresh mock data (teachers, students, exams, questions, admins)
  4. Upload all generated data to the cluster

Options:
  --help, -h    Show this help message

Note: Make sure your MongoDB connection string in database_config.dart is correct.
''');
    exit(0);
  }

  try {
    print('\n${'='.padRight(60, '=')}');
    print('MOCK DATA GENERATOR - STANDALONE SCRIPT');
    print('='.padRight(60, '='));
    print('');
    
    print('⚠ WARNING: This will drop and recreate the entire database!');
    print('⚠ All existing data will be permanently deleted!\n');
    
    // Generate and upload mock data
    // The generateBatch method with uploadToMongoDB: true will:
    // - Initialize AtlasService
    // - Drop the entire database
    // - Generate mock data
    // - Upload everything to MongoDB
    print('Starting mock data generation and upload...\n');
    
    final mockData = await MockDataGenerator.generateBatch(uploadToMongoDB: true);
    
    // Print summary
    print('\n${'='.padRight(60, '=')}');
    print('GENERATION COMPLETE');
    print('='.padRight(60, '='));
    print('\nGenerated Data Summary:');
    print('  • Teachers: ${mockData['teachers']?.length ?? 0}');
    print('  • Students: ${mockData['students']?.length ?? 0}');
    print('  • Exams: ${mockData['exams']?.length ?? 0}');
    print('  • Questions: ${mockData['questions']?.length ?? 0}');
    print('  • Admins: ${mockData['admins']?.length ?? 0}');
    print('\n✓ All data has been uploaded to MongoDB Atlas!');
    print('${'='.padRight(60, '=')}\n');
    
    // Close the connection
    await AtlasService.close();
    
    exit(0);
  } catch (e, stackTrace) {
    print('\n${'='.padRight(60, '=')}');
    print('ERROR OCCURRED');
    print('='.padRight(60, '='));
    print('\n❌ Failed to generate/upload mock data:');
    print('Error: $e');
    print('\nStack trace:');
    print(stackTrace);
    print('${'\n='.padRight(60, '=')}\n');
    
    // Make sure to close connection even on error
    try {
      await AtlasService.close();
    } catch (e) {
      // Ignore errors when closing
    }
    
    exit(1);
  }
}
