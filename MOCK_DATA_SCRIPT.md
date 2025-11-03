# Mock Data Generator Script

This standalone script generates mock data and uploads it to MongoDB Atlas. It can be run independently from the Flutter app.

## Usage

Run the script from the project root:

```bash
dart run lib/scripts/generate_mock_data.dart
```

Or with help:

```bash
dart run lib/scripts/generate_mock_data.dart --help
```

## What It Does

1. **Connects to MongoDB Atlas** - Uses the connection string from `lib/config/database_config.dart`
2. **Drops the entire database** - ⚠️ **WARNING**: This permanently deletes ALL existing data!
3. **Generates fresh mock data**:
   - Teachers (5 default)
   - Students (20 default)
   - Exams (3 per teacher)
   - Questions (5 per exam)
   - Admin users (2)
4. **Uploads all data** to MongoDB Atlas cluster

## Requirements

- MongoDB Atlas connection string configured in `lib/config/database_config.dart`
- Network access to MongoDB Atlas cluster
- Dart SDK installed (comes with Flutter)

## Example Output

```
============================================================
MOCK DATA GENERATOR - STANDALONE SCRIPT
============================================================

⚠ WARNING: This will drop and recreate the entire database!
⚠ All existing data will be permanently deleted!

Starting mock data generation and upload...

=== Starting MongoDB Upload Process ===
Initializing MongoDB connection...
Connecting to MongoDB Atlas...
Database: exam_management
✓ Successfully connected to MongoDB Atlas
✓ Connected to database: exam_management

⚠ DROPPING ENTIRE DATABASE AND REPLACING WITH NEW MOCK DATA...
⚠ This will delete ALL existing data in the database!
⚠ WARNING: Dropping entire database: exam_management
This will delete ALL data in the database!
✓ Database dropped successfully
Reconnecting to database...
Ensuring collections exist...
✓ All collections ensured
✓ Database recreated and ready for new data

Uploading generated mock data to MongoDB...
...
✓ All mock data uploaded to MongoDB successfully!
```

## Notes

- The script will completely replace all data in the database
- Make sure you have a backup if you need to preserve existing data
- The script handles connection management and cleanup automatically
- If an error occurs, the script will print detailed error information

