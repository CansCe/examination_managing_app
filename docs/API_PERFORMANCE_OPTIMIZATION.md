# API Performance Optimization Guide

This guide explains various strategies to make REST API calls faster in the Exam Management App.

## Current Implementation

The app uses `http.Client` for API calls. Here are optimization strategies:

## 1. HTTP Connection Reuse (Keep-Alive)

**Current Issue**: Each request creates a new connection.

**Solution**: Use a persistent HTTP client with connection pooling.

```dart
// In api_service.dart
class ApiService {
  // Use a persistent client with keep-alive
  static final http.Client _persistentClient = http.Client();
  
  final http.Client _client;
  
  ApiService({http.Client? client, String? baseUrl, String? chatBaseUrl})
      : _client = client ?? _persistentClient, // Reuse persistent client
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _chatBaseUrl = chatBaseUrl ?? ApiConfig.chatBaseUrl;
}
```

**Benefits**: 
- Reduces connection overhead
- Faster subsequent requests
- Lower server load

## 2. Parallel Requests

**Current Issue**: Sequential API calls (teachers, students, exams loaded one after another).

**Solution**: Use `Future.wait()` to make parallel requests.

```dart
// Before (Sequential - Slow)
final teachers = await AtlasService.findTeachers();
final students = await AtlasService.findStudents();
final exams = await AtlasService.findExams();

// After (Parallel - Fast)
final results = await Future.wait([
  AtlasService.findTeachers(),
  AtlasService.findStudents(),
  AtlasService.findExams(),
]);
final teachers = results[0];
final students = results[1];
final exams = results[2];
```

**Benefits**:
- 3x faster for 3 sequential calls
- Better user experience

## 3. Response Caching

**Current Issue**: Same data fetched repeatedly.

**Solution**: Cache API responses locally.

```dart
// Use ApiCacheService
final cacheKey = 'exams_$page';
final cached = await ApiCacheService.getCachedList(cacheKey);

if (cached != null) {
  // Return cached data immediately
  return cached;
}

// Fetch from API
final exams = await api.getExams(page: page);

// Cache for future use
await ApiCacheService.setCachedList(
  cacheKey,
  exams,
  duration: Duration(minutes: 5),
);

return exams;
```

**Benefits**:
- Instant response for cached data
- Reduced API calls
- Works offline for cached data

## 4. Request Batching

**Current Issue**: Multiple small requests for related data.

**Solution**: Create batch endpoints or combine requests.

```dart
// Instead of:
final exam = await api.getExam(examId);
final questions = await api.getQuestions(examId: examId);
final students = await api.getStudentsAssignedToExam(examId);

// Use batch endpoint:
final batchData = await api.getExamDetailsBatch(examId);
// Returns: {exam, questions, students}
```

**Backend**: Create `/api/exams/:id/details` endpoint that returns all related data.

## 5. Pagination Optimization

**Current Issue**: Loading all data at once.

**Solution**: Use efficient pagination with proper limits.

```dart
// Good: Load in chunks
Future<List<Exam>> loadExams() async {
  final allExams = <Exam>[];
  int page = 0;
  const limit = 50; // Optimal page size
  
  while (true) {
    final batch = await api.getExams(page: page, limit: limit);
    if (batch.isEmpty) break;
    
    allExams.addAll(batch);
    if (batch.length < limit) break; // Last page
    page++;
  }
  
  return allExams;
}
```

**Benefits**:
- Faster initial load
- Lower memory usage
- Better for large datasets

## 6. Lazy Loading

**Current Issue**: Loading all data upfront.

**Solution**: Load data only when needed.

```dart
// Load data on-demand
class ExamListWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        // Load more when scrolling near end
        if (index >= _exams.length - 5) {
          _loadMoreExams();
        }
        return ExamCard(_exams[index]);
      },
    );
  }
}
```

## 7. Compression

**Current Issue**: Large JSON payloads.

**Solution**: Enable gzip compression on backend and client.

**Backend** (Express):
```javascript
const compression = require('compression');
app.use(compression());
```

**Client** (Flutter):
```dart
final response = await _client.get(
  uri,
  headers: {
    'accept': 'application/json',
    'accept-encoding': 'gzip', // Request compression
  },
);
```

**Benefits**:
- 70-90% smaller payloads
- Faster transfer
- Lower bandwidth usage

## 8. Optimistic Updates

**Current Issue**: Waiting for API response before updating UI.

**Solution**: Update UI immediately, sync in background.

```dart
Future<void> updateStudent(Student student) async {
  // Update UI immediately
  setState(() {
    _students[_students.indexOf(student)] = updatedStudent;
  });
  
  try {
    // Sync in background
    await api.updateStudent(student);
  } catch (e) {
    // Revert on error
    setState(() {
      _students[_students.indexOf(updatedStudent)] = student;
    });
    showError('Failed to update student');
  }
}
```

**Benefits**:
- Instant UI feedback
- Better perceived performance

## 9. Background Prefetching

**Current Issue**: Loading data when user navigates.

**Solution**: Prefetch data in background.

```dart
class HomeScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // Prefetch data in background
    _prefetchData();
  }
  
  Future<void> _prefetchData() async {
    // Load data before user needs it
    await Future.wait([
      _loadTeachers(),
      _loadStudents(),
      _loadExams(),
    ]);
  }
}
```

## 10. Request Deduplication

**Current Issue**: Multiple identical requests.

**Solution**: Track pending requests and reuse them.

```dart
class ApiService {
  final Map<String, Future<dynamic>> _pendingRequests = {};
  
  Future<List<Exam>> getExams({int page = 0}) async {
    final key = 'exams_$page';
    
    // Return existing request if pending
    if (_pendingRequests.containsKey(key)) {
      return await _pendingRequests[key] as List<Exam>;
    }
    
    // Create new request
    final future = _fetchExams(page);
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _pendingRequests.remove(key);
    }
  }
}
```

## 11. Reduce Payload Size

**Current Issue**: Fetching unnecessary fields.

**Solution**: Request only needed fields.

```dart
// Instead of full object:
final exam = await api.getExam(examId);

// Request only needed fields:
final examSummary = await api.getExamSummary(examId);
// Returns: {id, title, date} instead of full object
```

**Backend**: Create lightweight endpoints or use query parameters:
```
GET /api/exams/:id?fields=id,title,date
```

## 12. Use HTTP/2

**Current Issue**: HTTP/1.1 limitations.

**Solution**: Upgrade to HTTP/2 (if server supports).

**Benefits**:
- Multiplexing (multiple requests over one connection)
- Header compression
- Server push

## Implementation Priority

1. **High Impact, Easy**:
   - ✅ Parallel requests (Future.wait)
   - ✅ HTTP connection reuse
   - ✅ Response caching

2. **High Impact, Medium Effort**:
   - Request batching
   - Compression
   - Lazy loading

3. **Medium Impact**:
   - Optimistic updates
   - Background prefetching
   - Request deduplication

## Example: Optimized Data Loading

```dart
Future<void> _loadDataOptimized() async {
  setState(() => _isLoading = true);
  
  try {
    // 1. Try cache first
    final cached = await ApiCacheService.getCachedList('home_data');
    if (cached != null) {
      setState(() {
        _exams = cached;
        _isLoading = false;
      });
    }
    
    // 2. Load in parallel
    final results = await Future.wait([
      api.getExams(),
      api.getStudents(),
      api.getTeachers(),
    ]);
    
    // 3. Update UI
    setState(() {
      _exams = results[0];
      _students = results[1];
      _teachers = results[2];
      _isLoading = false;
    });
    
    // 4. Cache for next time
    await ApiCacheService.setCachedList(
      'home_data',
      results[0],
      duration: Duration(minutes: 5),
    );
  } catch (e) {
    // Handle error
  }
}
```

## Monitoring Performance

Add timing to measure improvements:

```dart
final stopwatch = Stopwatch()..start();
final data = await api.getExams();
stopwatch.stop();
print('API call took: ${stopwatch.elapsedMilliseconds}ms');
```

## Next Steps

1. Implement `ApiCacheService` (already created)
2. Update `ApiService` to use persistent client
3. Convert sequential calls to parallel in `home_page.dart`
4. Add caching to frequently accessed endpoints
5. Enable compression on backend

---

**Last Updated**: 2024

