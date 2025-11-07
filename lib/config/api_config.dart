class ApiConfig {
  // Main API URL (MongoDB backend)
  // Change this when deploying the backend to a server.
  // For Android emulator use http://10.0.2.2:3000
  static const String baseUrl = 'http://localhost:3000';
  
  // Chat Service URL (Supabase backend)
  // Change this when deploying the chat service separately.
  // For Android emulator use http://10.0.2.2:3001
  static const String chatBaseUrl = 'http://localhost:3001';
}

