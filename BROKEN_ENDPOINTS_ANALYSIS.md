# CLARITY Backend Endpoints Analysis

## Base URL
- Production: `https://clarity.novamindnyc.com`

## Endpoint Status Analysis

### ❌ BROKEN/MISSING ENDPOINTS

1. **Chat Endpoint**
   - Frontend expects: `POST /api/v1/insights/chat`
   - Status: **DOES NOT EXIST** (returns 405)
   - Used by: ChatViewModel for AI conversations
   - Fix: Either implement on backend OR use existing insights endpoint

2. **User Sync After Cognito**
   - Frontend sends: `POST /api/v1/auth/login` with empty password
   - Status: **FAILS** - backend expects real password
   - Problem: Backend doesn't understand Cognito-authenticated users
   - Fix: Create new endpoint that accepts Cognito tokens

### ⚠️ UNTESTED ENDPOINTS

1. **Health Data Upload**
   - Endpoint: `POST /api/v1/health/upload`
   - Status: Unknown - never successfully called
   - Used by: HealthKit sync
   - Need to verify format and test

2. **PAT Analysis**
   - Endpoint: `POST /api/v1/pat/analyze/steps`
   - Status: Unknown - no real data sent
   - Used by: PAT analysis feature
   - Need to verify request format

3. **Insights Generation**
   - Endpoint: `POST /api/v1/insights`
   - Status: Unknown - may work but untested
   - Used by: Dashboard insights
   - Need to verify with real data

### ✅ POSSIBLY WORKING ENDPOINTS

1. **Authentication (Cognito)**
   - AWS Cognito endpoints work
   - But backend sync fails after Cognito success

2. **Service Health**
   - Endpoint: `GET /api/v1/insights/alerts`
   - May work but returns unknown format

## Required Backend Changes

### 1. **New Endpoint: Cognito User Sync**
```
POST /api/v1/auth/sync-cognito
Headers:
  Authorization: Bearer {cognito_access_token}
Body:
  {
    "cognitoUserId": "string",
    "email": "string",
    "deviceInfo": { ... }
  }
Response:
  {
    "user": { ... },
    "tokens": { ... }
  }
```

### 2. **Fix or Document: Chat Endpoint**
Option A: Implement chat endpoint
```
POST /api/v1/insights/chat
Body:
  {
    "message": "string",
    "context": {
      "conversationId": "string",
      "focusTimeframe": "string"
    }
  }
```

Option B: Use existing insights endpoint with chat mode
```
POST /api/v1/insights
Body:
  {
    "insightType": "chat_response",
    "context": "user_message",
    ...
  }
```

### 3. **Document: Health Upload Format**
Need to know exact format for:
- Batch health metrics upload
- Individual metric types
- Timestamp formats
- Required fields

### 4. **Document: PAT Analysis Format**
Need to know:
- Minimum data requirements
- Step count format
- Time window requirements
- Response format

## Testing Plan

1. **Use Postman/curl to test each endpoint**
2. **Document working request/response pairs**
3. **Update frontend to match actual backend**
4. **Add proper error handling for each failure**

## Frontend Code Locations

- Auth sync: `/Core/Services/AuthService.swift:276`
- Chat endpoint: `/Core/Networking/InsightEndpoint.swift:19`
- Health upload: `/Core/Services/HealthKitService.swift`
- PAT analysis: `/Features/Analysis/PATAnalysisViewModel.swift`

## Next Steps

1. Get backend API documentation
2. Test each endpoint manually
3. Fix frontend to match actual backend
4. Remove non-existent endpoints
5. Add proper error handling

---

*This document should be updated as we test each endpoint*