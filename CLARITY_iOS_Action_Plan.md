# CLARITY iOS Frontend Action Plan

## 🎯 SYSTEMATIC FIX IMPLEMENTATION PLAN

Based on the SPARC research analysis, here's the detailed implementation plan to make the CLARITY iOS app a proper wrapper for the backend API.

## 🚀 PHASE 1: API FOUNDATION (CRITICAL - 2-3 days)

### **1.1 Fix BackendAPIClient.swift**

#### **Current Issue**: All methods return `APIError.notImplemented`
```swift
// BROKEN - Current implementation
func getInsights() async throws -> [AIInsight] {
    throw APIError.notImplemented
}
```

#### **Required Fix**: Implement real HTTP calls
```swift
// WORKING - Required implementation
func getInsights(request: InsightGenerationRequest) async throws -> InsightGenerationResponse {
    let endpoint = "/api/v1/insights/"
    let response: InsightGenerationResponse = try await post(endpoint, body: request)
    return response
}

func getChatHistory(userId: String) async throws -> [ChatMessage] {
    let endpoint = "/api/v1/insights/history/\(userId)"
    let response: InsightHistoryResponse = try await get(endpoint)
    return response.data.messages ?? []
}
```

#### **Files to Modify**:
- `clarity-loop-frontend/Core/Networking/BackendAPIClient.swift`
- `clarity-loop-frontend/Core/Networking/APIEndpoints.swift`
- `clarity-loop-frontend/Data/DTOs/` (all DTO files)

### **1.2 Create Backend-Matching Models**

#### **Backend Models** (from Python):
```python
class InsightGenerationRequest(BaseModel):
    analysis_results: dict[str, Any]
    context: str | None
    insight_type: str = "comprehensive"
    include_recommendations: bool = True
    language: str = "en"
```

#### **Required iOS Models**:
```swift
struct InsightGenerationRequest: Codable {
    let analysisResults: [String: AnyCodable]
    let context: String?
    let insightType: String
    let includeRecommendations: Bool
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case analysisResults = "analysis_results"
        case context
        case insightType = "insight_type"
        case includeRecommendations = "include_recommendations"
        case language
    }
}
```

### **1.3 Implement HTTP Client Foundation**

#### **Add to BackendAPIClient.swift**:
```swift
private func makeRequest<T: Codable>(
    endpoint: String,
    method: HTTPMethod,
    body: Encodable? = nil
) async throws -> T {
    let url = baseURL.appendingPathComponent(endpoint)
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    
    // Add Authorization header
    if let token = await tokenProvider() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    // Add body if provided
    if let body = body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }
    
    guard 200...299 ~= httpResponse.statusCode else {
        throw APIError.serverError(httpResponse.statusCode)
    }
    
    return try JSONDecoder().decode(T.self, from: data)
}
```

## 🚀 PHASE 2: CORE FEATURES (3-4 days)

### **2.1 Fix Chat Feature**

#### **Current Issue**: ChatViewModel calls non-existent methods
```swift
// BROKEN - Current ChatViewModel
@MainActor
func sendMessage(_ content: String) async {
    // This calls a stub method that throws notImplemented
    let response = try await apiClient.sendChatMessage(content)
}
```

#### **Required Fix**: Implement real chat functionality
```swift
// WORKING - Fixed ChatViewModel
@MainActor
func sendMessage(_ content: String) async {
    do {
        let request = InsightGenerationRequest(
            analysisResults: [:],
            context: content,
            insightType: "chat_response",
            includeRecommendations: true,
            language: "en"
        )
        
        let response = try await apiClient.generateInsights(request: request)
        
        let aiMessage = ChatMessage(
            id: UUID(),
            content: response.data.narrative,
            isFromUser: false,
            timestamp: Date()
        )
        
        messages.append(aiMessage)
    } catch {
        errorMessage = "Failed to send message: \(error.localizedDescription)"
    }
}
```

#### **Add WebSocket Support**:
```swift
class WebSocketChatManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    @Published var messages: [ChatMessage] = []
    
    func connect(roomId: String, token: String) {
        let url = URL(string: "wss://clarity.novamindnyc.com/api/v1/ws/\(roomId)?token=\(token)")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessages()
    }
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    self?.handleData(data)
                @unknown default:
                    break
                }
                self?.receiveMessages()
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
}
```

### **2.2 Fix HealthKit Integration**

#### **Current Issue**: No batch upload to backend
```swift
// BROKEN - Current HealthKitService
func syncAllHealthData() async {
    // This doesn't actually upload to backend
    // Just stores locally in SwiftData
}
```

#### **Required Fix**: Implement backend upload
```swift
// WORKING - Fixed HealthKitService
func syncAllHealthData() async {
    do {
        // 1. Fetch from HealthKit
        let healthData = try await fetchLatestHealthData()
        
        // 2. Convert to backend format
        let uploadRequest = HealthKitUploadRequest(
            userId: getCurrentUserId(),
            dataPoints: healthData.map { $0.toBackendFormat() },
            timestamp: Date()
        )
        
        // 3. Upload to backend
        try await apiClient.uploadHealthKitData(request: uploadRequest)
        
        // 4. Store locally after successful upload
        try await localRepository.store(healthData)
        
    } catch {
        print("Health sync failed: \(error)")
        // Queue for retry
        await offlineQueue.add(operation: .healthSync)
    }
}
```

#### **Add Background Sync**:
```swift
func setupBackgroundSync() {
    // Configure background app refresh
    let identifier = "com.novamindnyc.clarity.healthsync"
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    try? BGTaskScheduler.shared.submit(request)
}
```

### **2.3 Fix Dashboard Analytics**

#### **Current Issue**: Shows "Oops, something went wrong"
```swift
// BROKEN - Current DashboardViewModel
@Published var insights: [AIInsight] = []
@Published var viewState: ViewState<[AIInsight]> = .idle

func loadInsights() async {
    // This fails because API returns notImplemented
}
```

#### **Required Fix**: Connect to real backend data
```swift
// WORKING - Fixed DashboardViewModel
@MainActor
func loadDashboardData() async {
    viewState = .loading
    
    do {
        async let insights = apiClient.getInsightHistory(userId: currentUserId)
        async let patAnalysis = apiClient.getPATAnalysis(userId: currentUserId)
        async let healthMetrics = apiClient.getHealthMetrics(userId: currentUserId)
        
        let (insightData, patData, metricsData) = try await (insights, patAnalysis, healthMetrics)
        
        self.insights = insightData
        self.patAnalysis = patData
        self.healthMetrics = metricsData
        
        viewState = .success(insightData)
        
    } catch {
        viewState = .error(error)
        errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
    }
}
```

### **2.4 Fix Authentication Headers**

#### **Current Issue**: API calls don't include auth tokens
```swift
// BROKEN - Missing auth headers
var request = URLRequest(url: url)
request.httpMethod = "GET"
// No Authorization header!
```

#### **Required Fix**: Add proper authentication
```swift
// WORKING - With auth headers
private func authenticatedRequest(for url: URL, method: HTTPMethod) async throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    
    // Get current JWT token from Amplify
    let session = try await Amplify.Auth.fetchAuthSession()
    if let tokenProvider = session as? AuthCognitoTokensProvider {
        let tokens = try tokenProvider.getCognitoTokens().get()
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    return request
}
```

## 🚀 PHASE 3: TESTING & POLISH (2-3 days)

### **3.1 End-to-End Testing**

#### **Test Scenarios**:
1. **Chat Flow**: Send message → Get AI response → Verify in UI
2. **HealthKit Flow**: Sync Apple Watch data → Upload to backend → Verify dashboard
3. **Authentication Flow**: Login → Get token → Make API calls → Verify auth
4. **Error Handling**: Network failure → Show error state → Retry logic

#### **Test Implementation**:
```swift
func testChatEndToEnd() async throws {
    // 1. Setup authenticated user
    let chatViewModel = ChatViewModel(apiClient: realAPIClient)
    
    // 2. Send message
    await chatViewModel.sendMessage("How is my sleep?")
    
    // 3. Verify response
    XCTAssertTrue(chatViewModel.messages.count >= 2)
    XCTAssertFalse(chatViewModel.messages.last?.isFromUser ?? true)
    XCTAssertFalse(chatViewModel.messages.last?.content.isEmpty ?? true)
}
```

### **3.2 Error State Handling**

#### **Add Comprehensive Error UI**:
```swift
struct ErrorStateView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## 📋 IMPLEMENTATION CHECKLIST

### **Phase 1: API Foundation**
- [ ] Replace all `APIError.notImplemented` methods in BackendAPIClient
- [ ] Create backend-matching request/response models
- [ ] Implement HTTP client with auth headers
- [ ] Test all endpoints with curl/Postman
- [ ] Add proper error handling and retry logic

### **Phase 2: Core Features**
- [ ] Fix ChatViewModel to use real API calls
- [ ] Implement WebSocket connection for real-time chat
- [ ] Fix HealthKit batch upload to backend
- [ ] Connect Dashboard to real backend analytics
- [ ] Ensure all API calls include proper auth tokens

### **Phase 3: Testing & Polish**
- [ ] Write end-to-end tests for all major flows
- [ ] Implement comprehensive error state handling
- [ ] Test with real Apple Watch data
- [ ] Performance testing and optimization
- [ ] Production deployment preparation

## 🔥 IMMEDIATE FIRST STEPS

1. **Start with BackendAPIClient.swift** - Replace the first stub method with real implementation
2. **Test one endpoint** - Verify `/api/v1/insights/` works with curl
3. **Fix one feature** - Get chat working end-to-end first
4. **Iterate rapidly** - Fix one feature at a time, test immediately

---

**EXECUTION STRATEGY**: Start with the smallest possible working feature (chat), get it working end-to-end, then systematically fix each feature using the same pattern. This ensures rapid progress and immediate feedback. 