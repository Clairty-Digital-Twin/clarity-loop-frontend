# Phase 2: Backend Integration Fix Implementation Plan

## Problem Summary
Multiple API endpoints either don't exist or are being called incorrectly, resulting in 405 errors and no data flow.

## Root Causes
1. Chat endpoint `/api/v1/insights/chat` doesn't exist on backend
2. Error handling hides real problems (shows "cancelled")
3. No endpoint documentation to verify correct usage
4. APIService routing is overly complex

## Fix Implementation Steps

### Step 1: Test All Endpoints Manually
Create test script to verify each endpoint:

```bash
#!/bin/bash
# File: test_endpoints.sh

BASE_URL="https://clarity.novamindnyc.com"
TOKEN="your-cognito-token-here"

# Test insights generation
curl -X POST "$BASE_URL/api/v1/insights" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"context": "test", "insightType": "daily_summary"}'

# Test chat endpoint (expected to fail)
curl -X POST "$BASE_URL/api/v1/insights/chat" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}'

# Test health endpoints
curl -X GET "$BASE_URL/api/v1/health/metrics" \
  -H "Authorization: Bearer $TOKEN"
```

### Step 2: Fix Chat Implementation
**File**: `/Core/Services/InsightAIService.swift`

Replace chat endpoint with insights endpoint:

```swift
// Line 85-117 - REPLACE generateChatResponse
func generateChatResponse(
    userMessage: String,
    conversationHistory: [ChatMessage] = [],
    healthContext: [String: Any]? = nil
) async throws -> HealthInsightDTO {
    // Use insights endpoint with chat context
    let conversationContext = conversationHistory
        .map { "\($0.sender.rawValue): \($0.text)" }
        .joined(separator: "\n")
    
    let fullContext = """
    Conversation:
    \(conversationContext)
    User: \(userMessage)
    
    Please provide a helpful health-related response.
    """
    
    let request = InsightGenerationRequestDTO(
        analysisResults: healthContext?.mapValues { AnyCodable($0) } ?? [:],
        context: fullContext,
        insightType: "chat_response",
        includeRecommendations: false,
        language: "en"
    )
    
    let response = try await apiClient.generateInsight(requestDTO: request)
    return response.data
}
```

### Step 3: Fix Error Handling
**File**: `/Core/Networking/BackendAPIClient.swift`

Add detailed error logging:

```swift
// Line 190-197 - ENHANCE error handling
if httpResponse.statusCode >= 400 {
    // Log the actual error
    let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
    print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
    
    // Create specific error based on status code
    switch httpResponse.statusCode {
    case 404:
        throw APIError.endpointNotFound(path: endpoint.path)
    case 405:
        throw APIError.methodNotAllowed(path: endpoint.path)
    case 401:
        throw APIError.unauthorized
    case 500...599:
        throw APIError.serverError(code: httpResponse.statusCode, message: errorBody)
    default:
        throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
    }
}
```

### Step 4: Add Specific Error Types
**File**: `/Core/Networking/APIError.swift`

Add new error cases:

```swift
enum APIError: LocalizedError {
    // ... existing cases ...
    case endpointNotFound(path: String)
    case methodNotAllowed(path: String)
    
    var errorDescription: String? {
        switch self {
        case let .endpointNotFound(path):
            return "The endpoint '\(path)' does not exist on the server."
        case let .methodNotAllowed(path):
            return "The HTTP method is not allowed for '\(path)'."
        // ... other cases ...
        }
    }
}
```

### Step 5: Fix APIService Routing
**File**: `/Core/Networking/APIService.swift`

Simplify the routing logic:

```swift
// Line 193-207 - REPLACE performRequest
private func performRequest<T>(_ endpoint: APIEndpoint) async throws -> T {
    // Remove complex routing - let BackendAPIClient handle everything
    throw APIError.notImplemented
}
```

Make all calls go directly through BackendAPIClient instead of APIService.

### Step 6: Create Endpoint Documentation
**File**: `/API_DOCUMENTATION.md`

Document all working endpoints:

```markdown
# CLARITY API Documentation

## Base URL
Production: https://clarity.novamindnyc.com

## Authentication
All requests require Bearer token:
```
Authorization: Bearer {cognito_access_token}
```

## Endpoints

### Insights Generation
```
POST /api/v1/insights
Content-Type: application/json

Request:
{
  "analysisResults": {},
  "context": "string",
  "insightType": "daily_summary|chat_response|health_alert",
  "includeRecommendations": true,
  "language": "en"
}

Response:
{
  "data": {
    "userId": "string",
    "narrative": "string",
    "keyInsights": [],
    "recommendations": [],
    "confidenceScore": 0.95,
    "generatedAt": "2024-01-01T00:00:00Z"
  }
}
```

[Document other endpoints as discovered]
```

### Step 7: Update ViewModels to Show Real Errors
**File**: `/Features/Dashboard/DashboardViewModel.swift`

Show specific errors:

```swift
// Line 63-65 - ENHANCE error handling
} catch {
    print("❌ Dashboard error: \(error)")
    
    // Show specific error message
    if let apiError = error as? APIError {
        viewState = .error(apiError)
    } else {
        viewState = .error(error)
    }
}
```

## Testing Plan

1. **Test Each Endpoint**
   - Run test script for all endpoints
   - Document which ones work
   - Note exact error messages

2. **Test Error Display**
   - Force various errors
   - Verify specific messages show
   - No more "cancelled" errors

3. **Test Chat Alternative**
   - Use insights endpoint for chat
   - Verify responses make sense
   - Test conversation context

## Success Criteria
- [ ] No more 405 errors
- [ ] Real error messages displayed
- [ ] Chat works via insights endpoint
- [ ] All endpoints documented
- [ ] Error handling shows actionable messages

## Estimated Time: 2-3 Days

## Next Phase
Once API integration works, move to Phase 3: Health Data Sync

---

*This plan will be updated based on endpoint testing results*