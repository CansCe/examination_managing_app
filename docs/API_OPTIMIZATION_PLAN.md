# API Fetching Optimization Plan

## Current Issues
1. **Rate Limiting**: Each retry counts as a new request, making rate limits worse
2. **No Request Deduplication**: Same data fetched multiple times
3. **No Caching**: Data fetched repeatedly even when unchanged
4. **Sequential Requests**: No parallelization of independent requests
5. **No Request Batching**: Multiple small requests instead of one large request

## Optimization Strategies

### 1. **Smart Retry with Exponential Backoff & Rate Limit Headers**
```
┌─────────────────────────────────────────────────────────┐
│                    API Request Flow                      │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Make Request  │
                    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Check Status  │
                    └───────┬───────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
         Success        429 Rate      Other Error
            │            Limit            │
            │               │             │
            ▼               ▼             ▼
      Return Data    Read Headers    Retry Logic
                            │             │
                            │             │
                    ┌───────┴───────┐     │
                    │               │     │
            Retry-After      Exponential │
            Header           Backoff     │
                    │               │     │
                    └───────┬───────┘     │
                            │             │
                            └──────┬──────┘
                                   │
                                   ▼
                            Wait & Retry
                            (max 3 times)
```

**Implementation**:
- Read `Retry-After` header from 429 responses
- Use exponential backoff: 2s, 4s, 8s
- Don't count retries as new requests (wait before retrying)
- Cancel retry if user navigates away

### 2. **Request Caching Layer**
```
┌─────────────────────────────────────────────────────────┐
│                    Caching Strategy                     │
└─────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Memory     │      │   Disk       │      │   Network    │
│   Cache      │─────▶│   Cache      │─────▶│   Request    │
│   (5 min)    │      │   (1 hour)   │      │              │
└──────────────┘      └──────────────┘      └──────────────┘
     │                      │                      │
     │                      │                      │
     └──────────────────────┴──────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Return Data   │
                    └───────────────┘

Cache Keys:
- Exams: "exams:student:{studentId}:page:{page}"
- Questions: "questions:ids:{ids_hash}"
- Exam Details: "exam:{examId}"
- Student Results: "results:student:{studentId}"
```

**Cache Invalidation**:
- On exam update/delete
- On student assignment changes
- Time-based expiration (TTL)
- Manual refresh button

### 3. **Request Deduplication**
```
┌─────────────────────────────────────────────────────────┐
│              Request Deduplication Flow                 │
└─────────────────────────────────────────────────────────┘

Request 1: GET /api/exams?page=0
    │
    ├─▶ Check: Is same request in-flight?
    │       │
    │       ├─ Yes ──▶ Join existing request (Future)
    │       │
    │       └─ No ───▶ Create new request
    │                      │
    │                      ▼
    │              Store in-flight request
    │                      │
    │                      ▼
    │              Make HTTP request
    │                      │
    │                      ▼
    │              Remove from in-flight
    │                      │
    │                      ▼
    │              Return result to all waiters
    │
Request 2: GET /api/exams?page=0 (same request)
    │
    └─▶ Join Request 1's Future
            │
            ▼
    Wait for same result
```

**Implementation**:
- Map of in-flight requests: `Map<String, Future<T>>`
- Key format: `"GET:/api/exams?page=0"`
- Multiple callers share same Future
- Clean up after completion

### 4. **Parallel Request Batching**
```
┌─────────────────────────────────────────────────────────┐
│            Parallel vs Sequential Requests              │
└─────────────────────────────────────────────────────────┘

Sequential (Current):
┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐
│Exam1│───▶│Exam2│───▶│Exam3│───▶│Exam4│
└─────┘    └─────┘    └─────┘    └─────┘
Total: 4 × 200ms = 800ms

Parallel (Optimized):
┌─────┐
│Exam1│
└─────┘
┌─────┐
│Exam2│
└─────┘
┌─────┐
│Exam3│
└─────┘
┌─────┐
│Exam4│
└─────┘
Total: max(200ms) = 200ms (4x faster)
```

**Implementation**:
- Use `Future.wait()` for independent requests
- Batch question fetching: `getQuestionsByIds([id1, id2, id3])`
- Load exam details in parallel with questions

### 5. **Data Prefetching**
```
┌─────────────────────────────────────────────────────────┐
│                  Prefetching Strategy                   │
└─────────────────────────────────────────────────────────┘

User Action: View Exam List
    │
    ├─▶ Load Page 0 (visible)
    │
    └─▶ Prefetch Page 1 (background)
            │
            └─▶ Prefetch Questions for visible exams
                    │
                    └─▶ Prefetch Exam Details on hover
```

**Implementation**:
- Prefetch next page when scrolling near bottom
- Prefetch questions when exam card is visible
- Cancel prefetch if user navigates away

### 6. **Request Compression & Connection Reuse**
```
┌─────────────────────────────────────────────────────────┐
│              Network Optimization                       │
└─────────────────────────────────────────────────────────┘

✅ Already Implemented:
- HTTP Keep-Alive (connection reuse)
- Gzip compression (accept-encoding: gzip)

🔄 Can Improve:
- HTTP/2 multiplexing (if server supports)
- Request pipelining
- Response compression verification
```

### 7. **Backend Optimizations**
```
┌─────────────────────────────────────────────────────────┐
│              Backend Improvements                      │
└─────────────────────────────────────────────────────────┘

1. Database Indexing:
   - Index on examDate, examTime
   - Index on studentId in exam_results
   - Index on examId in questions

2. Response Pagination:
   - Increase default page size (20 → 50)
   - Add cursor-based pagination
   - Return total count in headers

3. Batch Endpoints:
   - GET /api/questions/batch?ids=id1,id2,id3
   - GET /api/exams/batch?ids=id1,id2,id3
   - POST /api/exams/batch (bulk operations)

4. Field Selection:
   - GET /api/exams?fields=id,title,date (only needed fields)
   - Reduce payload size

5. Rate Limit Headers:
   - X-RateLimit-Limit: 500
   - X-RateLimit-Remaining: 450
   - X-RateLimit-Reset: 1234567890
   - Retry-After: 60 (for 429)
```

## Implementation Priority

### Phase 1: Quick Wins (High Impact, Low Effort)
1. ✅ Smart retry with exponential backoff
2. ✅ Request deduplication
3. ✅ Read rate limit headers

### Phase 2: Caching (Medium Effort, High Impact)
4. Memory cache for frequently accessed data
5. Cache invalidation on updates
6. TTL-based expiration

### Phase 3: Parallelization (Medium Effort, Medium Impact)
7. Parallel request batching
8. Prefetching next page
9. Background question loading

### Phase 4: Backend (Requires Backend Changes)
10. Database indexing
11. Batch endpoints
12. Field selection API

## Expected Performance Improvements

| Optimization | Current | Optimized | Improvement |
|-------------|---------|-----------|-------------|
| Initial Load | 2-3s | 0.5-1s | 3-6x faster |
| Page Navigation | 1-2s | 0.2-0.5s | 4-5x faster |
| Rate Limit Hits | Frequent | Rare | 90% reduction |
| Network Requests | 50+ | 10-15 | 70% reduction |
| Data Transfer | 500KB | 200KB | 60% reduction |

## Code Structure

```
lib/
├── services/
│   ├── api_service.dart (enhanced with retry logic)
│   ├── api_cache_service.dart (NEW - caching layer)
│   └── request_deduplicator.dart (NEW - deduplication)
├── utils/
│   └── retry_handler.dart (NEW - smart retry logic)
└── models/
    └── cache_entry.dart (NEW - cache data structure)
```

