class DatabaseConfig {
  // Replace this with your MongoDB Atlas connection string
  static const String connectionString =
      'mongodb+srv://admin1:ANHC180723@clustertest.7nkaqoh.mongodb.net/?retryWrites=true&w=majority&appName=ClusterTest';
  
  // Database name
  static const String databaseName = 'exam_management';
  
  // Collection names
  static const String examsCollection = 'exams';
  static const String studentsCollection = 'students';
  static const String teachersCollection = 'teachers';
  static const String questionsCollection = 'questions';
  static const String usersCollection = 'users';
} 