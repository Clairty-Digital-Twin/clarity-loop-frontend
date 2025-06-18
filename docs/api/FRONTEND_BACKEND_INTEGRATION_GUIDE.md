# Frontend-Backend Integration Guide

## Overview
This guide details how the CLARITY Loop iOS frontend integrates with the AWS-hosted backend, covering architecture patterns, data flow, error handling, and best practices.

## Integration Architecture

### Contract Adapter Pattern
The frontend uses a Contract Adapter Pattern to decouple backend API contracts from internal domain models:

```
Backend API → DTOs → Adapters → Domain Models → ViewModels → Views
```

### Key Components

#### 1. API Client (`Core/Networking/APIClient.swift`)
- Centralized HTTP client for all backend communication
- Handles authentication headers automatically
- Implements retry logic and error mapping
- Base URL: `https://clarity.novamindnyc.com/api/v1`

#### 2. DTOs (Data Transfer Objects)
Located in `Data/DTOs/`:
- `AuthLoginDTOs.swift` - Authentication request/response structures
- `UserSessionResponseDTO.swift` - User session data
- `HealthDataDTOs.swift` - Health data upload/retrieval
- `InsightDTOs.swift` - AI insight structures

#### 3. Backend Contract Adapter
**Location**: `Core/Adapters/BackendContractAdapter.swift`
- Maps DTOs to domain models
- Handles data transformation
- Validates backend responses
- Provides fallback values

#### 4. Repository Layer
Implements data access patterns:
```swift
protocol UserRepository {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws -> User
    func syncWithBackend() async throws
}
```

## Authentication Integration

### Token Flow
```swift
// 1. Login request
let loginDTO = LoginRequestDTO(email: email, password: password)
let response = try await apiClient.post("/auth/login", body: loginDTO)

// 2. Amplify handles token storage
// Tokens automatically included in subsequent requests

// 3. Token refresh handled by Amplify
// No manual refresh needed
```

### Auth State Synchronization
```swift
// AuthService monitors Amplify Hub for auth events
Amplify.Hub.listen(to: .auth) { payload in
    switch payload.eventName {
    case HubPayload.EventName.Auth.signedIn:
        // Sync user with backend
        await syncUserWithBackend()
    case HubPayload.EventName.Auth.sessionExpired:
        // Handle session expiry
        await handleSessionExpired()
    }
}
```

## Data Synchronization

### HealthKit to Backend Sync
```swift
// 1. Fetch HealthKit data
let healthData = try await healthKitService.fetchLatestData()

// 2. Transform to DTOs
let dtos = healthData.map { HealthDataDTO(from: $0) }

// 3. Bulk upload
let request = BulkUploadRequest(samples: dtos)
try await apiClient.post("/healthkit/bulk-upload", body: request)

// 4. Update sync status
await updateLastSyncTimestamp()
```

### Offline Support
```swift
// 1. Queue operations when offline
if !networkMonitor.isConnected {
    pendingOperations.append(operation)
    return
}

// 2. Process queue when online
networkMonitor.onConnectionRestored = {
    await processPendingOperations()
}
```

### Background Sync
```swift
// Background task for periodic sync
func scheduleBackgroundSync() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.clarity.healthsync",
        using: nil
    ) { task in
        await performBackgroundSync()
        task.setTaskCompleted(success: true)
    }
}
```

## Error Handling

### API Error Mapping
```swift
enum APIError: Error {
    case unauthorized(message: String)
    case validation(errors: [ValidationError])
    case serverError(code: String, message: String)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
}

// Error mapping in APIClient
func mapError(_ response: HTTPURLResponse, data: Data?) -> APIError {
    switch response.statusCode {
    case 401:
        return .unauthorized(message: extractMessage(from: data))
    case 422:
        return .validation(errors: extractValidationErrors(from: data))
    case 500...599:
        return .serverError(
            code: extractErrorCode(from: data),
            message: extractMessage(from: data)
        )
    default:
        return .networkError(underlying: URLError(.unknown))
    }
}
```

### User-Friendly Error Messages
```swift
extension APIError {
    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Please log in again to continue"
        case .validation(let errors):
            return errors.first?.message ?? "Please check your input"
        case .serverError:
            return "Something went wrong. Please try again"
        case .networkError:
            return "Check your internet connection"
        case .decodingError:
            return "Unable to process server response"
        }
    }
}
```

## Real-time Features

### WebSocket Integration
```swift
class ChatService {
    private var webSocket: URLSessionWebSocketTask?
    
    func connect() async throws {
        let url = URL(string: "wss://clarity.novamindnyc.com/api/v1/ws/chat")!
        var request = URLRequest(url: url)
        
        // Add auth token
        if let token = await authService.currentAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        await receiveMessages()
    }
    
    func send(_ message: ChatMessage) async throws {
        let data = try JSONEncoder().encode(message)
        try await webSocket?.send(.data(data))
    }
}
```

## Performance Optimization

### Request Batching
```swift
// Batch multiple health data uploads
class HealthDataUploader {
    private var pendingSamples: [HealthSample] = []
    private let batchSize = 100
    
    func queueSample(_ sample: HealthSample) {
        pendingSamples.append(sample)
        
        if pendingSamples.count >= batchSize {
            Task {
                await uploadBatch()
            }
        }
    }
    
    private func uploadBatch() async {
        let batch = Array(pendingSamples.prefix(batchSize))
        pendingSamples.removeFirst(min(batchSize, pendingSamples.count))
        
        try? await apiClient.post("/healthkit/bulk-upload", body: batch)
    }
}
```

### Response Caching
```swift
// Cache frequently accessed data
class UserProfileCache {
    private let cache = NSCache<NSString, CachedUser>()
    private let cacheExpiry: TimeInterval = 300 // 5 minutes
    
    func getCachedUser(id: String) -> User? {
        guard let cached = cache.object(forKey: id as NSString),
              cached.timestamp.timeIntervalSinceNow > -cacheExpiry else {
            return nil
        }
        return cached.user
    }
}
```

## Testing Integration

### Mock API Client
```swift
class MockAPIClient: APIClientProtocol {
    var mockResponses: [String: Any] = [:]
    
    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let response = mockResponses[path] as? T else {
            throw APIError.networkError(underlying: URLError(.badURL))
        }
        return response
    }
}
```

### Integration Tests
```swift
class AuthIntegrationTests: XCTestCase {
    func testLoginFlow() async throws {
        // Use test backend endpoint
        let apiClient = APIClient(baseURL: "https://test.clarity.novamindnyc.com")
        let authService = AuthService(apiClient: apiClient)
        
        // Test login
        let user = try await authService.signIn(
            email: "test@example.com",
            password: "testPassword123"
        )
        
        XCTAssertNotNil(user.id)
        XCTAssertEqual(user.email, "test@example.com")
    }
}
```

## Security Considerations

### Certificate Pinning
```swift
class PinnedURLSession: URLSession {
    override func dataTask(with request: URLRequest) -> URLSessionDataTask {
        // Implement certificate validation
        return super.dataTask(with: request)
    }
}
```

### Request Signing
```swift
// Add request signature for sensitive operations
extension URLRequest {
    mutating func addSignature(using key: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        setValue(timestamp, forHTTPHeaderField: "X-Request-Timestamp")
        
        let signature = generateSignature(
            method: httpMethod ?? "GET",
            path: url?.path ?? "",
            timestamp: timestamp,
            key: key
        )
        setValue(signature, forHTTPHeaderField: "X-Request-Signature")
    }
}
```

## Monitoring & Analytics

### Request Logging
```swift
class NetworkLogger {
    static func log(_ request: URLRequest, response: URLResponse?, error: Error?) {
        #if DEBUG
        print("🌐 \(request.httpMethod ?? "?") \(request.url?.path ?? "?")")
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        } else if let httpResponse = response as? HTTPURLResponse {
            print("✅ Status: \(httpResponse.statusCode)")
        }
        #endif
    }
}
```

### Performance Metrics
```swift
class APIMetrics {
    static func track(_ request: URLRequest, duration: TimeInterval, success: Bool) {
        // Send to analytics service
        Analytics.track("api_request", properties: [
            "endpoint": request.url?.path ?? "unknown",
            "duration_ms": Int(duration * 1000),
            "success": success
        ])
    }
}
```

## Best Practices

### 1. Always Use DTOs
- Never pass domain models directly to API
- Map responses through adapters
- Validate data at boundaries

### 2. Handle All Error Cases
- Network failures
- Auth expiration
- Validation errors
- Server errors

### 3. Implement Retry Logic
```swift
func withRetry<T>(maxAttempts: Int = 3, operation: () async throws -> T) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
    }
    
    throw lastError ?? APIError.networkError(underlying: URLError(.unknown))
}
```

### 4. Monitor API Health
- Track success rates
- Monitor response times
- Alert on errors
- Log for debugging

### 5. Version API Contracts
- Use versioned endpoints
- Maintain backward compatibility
- Document breaking changes
- Coordinate frontend/backend releases