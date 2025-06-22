# CLARITY iOS Backend Integration PRD

## Executive Summary
The CLARITY iOS app exists as a comprehensive SwiftUI application with clean architecture but is completely non-functional due to missing backend integration. All API methods return `APIError.notImplemented`, making core features (chat, analytics, health sync) unusable. This PRD defines the systematic implementation required to transform the app into a fully functional wrapper for the existing backend API.

## Current State Analysis

### ✅ What Works
- **Authentication**: AWS Amplify/Cognito integration functional
- **Architecture**: Clean MVVM + SwiftUI architecture in place
- **UI Components**: Complete SwiftUI views and ViewModels exist
- **HealthKit**: Permissions and local data collection working
- **Build System**: All compilation errors resolved, app builds successfully

### ❌ Critical Failures
- **API Integration**: All `BackendAPIClient.swift` methods return `APIError.notImplemented`
- **Chat Feature**: UI exists but no backend connection to Gemini AI
- **Health Data Sync**: HealthKit data stays local, never uploads to backend
- **Dashboard Analytics**: Shows error states instead of real PAT analysis
- **Real-time Features**: No WebSocket implementation for live chat

## Backend API Reference
**Base URL**: `https://clarity.novamindnyc.com`

### Available Endpoints
- `POST /api/v1/insights/` - Gemini AI chat functionality
- `WS /api/v1/ws/{room_id}` - Real-time WebSocket chat
- `POST /api/v1/healthkit/upload` - HealthKit data batch upload
- `GET /api/v1/health-data/` - Health data retrieval and aggregation
- `GET /api/v1/pat/analysis/{user_id}` - PAT analysis results
- `GET /api/v1/metrics/` - Health metrics and trends
- `POST /api/v1/auth/refresh` - JWT token refresh

## Technical Requirements

### Phase 1: Core API Integration (CRITICAL)
**Objective**: Replace all stub methods with real HTTP implementations

#### 1.1 Backend API Client Implementation
- Replace all `APIError.notImplemented` returns in `BackendAPIClient.swift`
- Implement proper HTTP methods using `URLSession`
- Add authentication headers with JWT tokens from Amplify
- Create request/response serialization logic
- Implement proper error handling and status code management

#### 1.2 Request/Response Models
- Create DTOs matching backend schemas exactly
- Implement `Codable` conformance with proper JSON key mapping
- Add validation for required fields
- Create type-safe response parsing

### Phase 2: Feature Implementation
**Objective**: Connect existing UI to backend services

#### 2.1 Chat Feature Integration
- Connect `ChatViewModel` to `/api/v1/insights/` endpoint
- Implement WebSocket connection for real-time messaging
- Add message persistence and history retrieval
- Implement typing indicators and message status
- Add error handling for failed messages

#### 2.2 HealthKit Backend Sync
- Implement batch upload to `/api/v1/healthkit/upload`
- Create background sync service with retry logic
- Add sync status tracking and UI indicators
- Implement Apple Watch data collection and transmission
- Handle large data payloads efficiently

#### 2.3 Dashboard Analytics
- Connect to `/api/v1/pat/analysis/{user_id}` for PAT data
- Fetch health metrics from `/api/v1/metrics/`
- Implement insight history from backend
- Add concurrent data loading with proper state management
- Create error states and retry mechanisms

### Phase 3: Real-time & Advanced Features
**Objective**: Implement advanced functionality

#### 3.1 WebSocket Manager
- Create WebSocket connection manager
- Implement connection state management
- Add heartbeat and reconnection logic
- Handle message encoding/decoding
- Integrate with existing chat UI

#### 3.2 Comprehensive Error Handling
- Create unified error handling system
- Implement user-friendly error messages
- Add retry logic for network failures
- Create offline queue management
- Implement proper logging for debugging

## Implementation Strategy

### Sprint 1: API Foundation (3-4 days)
1. **Day 1-2**: Replace API stub methods with real HTTP calls
2. **Day 2-3**: Create backend-matching DTOs and models
3. **Day 3-4**: Implement JWT authentication headers and token management

### Sprint 2: Core Features (4-5 days)
1. **Day 1-2**: Chat feature with REST API integration
2. **Day 2-3**: HealthKit batch upload and background sync
3. **Day 3-4**: Dashboard analytics connection
4. **Day 4-5**: Basic error handling and UX improvements

### Sprint 3: Advanced Features (2-3 days)
1. **Day 1-2**: WebSocket implementation for real-time chat
2. **Day 2-3**: Comprehensive error handling and offline support
3. **Day 3**: Testing, polish, and production readiness

## Success Criteria

### Functional Requirements
- ✅ User can chat with Gemini AI and receive health-aware responses
- ✅ Apple Watch health data automatically syncs to backend
- ✅ Dashboard displays real PAT analysis and health metrics
- ✅ Real-time chat with typing indicators works
- ✅ All features handle network failures gracefully
- ✅ Authentication flows work seamlessly across all features

### Technical Requirements
- ✅ All API endpoints return real data (no `notImplemented` errors)
- ✅ Proper error handling with user-friendly messages
- ✅ Background sync works reliably
- ✅ WebSocket connection maintains stability
- ✅ Performance meets iOS standards
- ✅ HIPAA compliance maintained

## File Structure & Implementation Focus

### Primary Files to Modify
```
clarity-loop-frontend/Core/Networking/
├── BackendAPIClient.swift          # CRITICAL: Replace all stub methods
├── APIError.swift                  # Enhance error types
└── WebSocketManager.swift          # NEW: Real-time functionality

clarity-loop-frontend/Data/DTOs/
├── BackendHealthDataDTOs.swift     # UPDATE: Match backend schemas
├── InsightsDTOs.swift              # UPDATE: Chat response models
└── PATAnalysisDTOs.swift          # UPDATE: Analytics models

clarity-loop-frontend/Features/
├── Insights/ChatViewModel.swift    # CONNECT: To real API
├── Dashboard/DashboardViewModel.swift # CONNECT: To analytics API
└── Health/HealthViewModel.swift    # CONNECT: To sync service
```

### Implementation Priorities
1. **Highest**: `BackendAPIClient.swift` - Foundation for everything
2. **High**: DTO models - Required for API communication
3. **High**: Chat and HealthKit integration - Core user value
4. **Medium**: Dashboard analytics - User engagement
5. **Medium**: WebSocket and advanced features - Enhanced UX

## Risk Mitigation

### Technical Risks
- **Backend Compatibility**: Backend is stable and documented ✅
- **Authentication**: AWS Amplify integration already working ✅
- **Data Models**: Backend schemas available for reference ✅
- **Testing**: Comprehensive test suite exists for validation ✅

### Timeline Risks
- **Complexity**: Breaking down into small, testable increments
- **Dependencies**: Clear dependency chain established
- **Validation**: Each phase has specific success criteria
- **Rollback**: Git-based version control for safe iteration

## Dependencies & Prerequisites

### External Dependencies
- Backend API at `https://clarity.novamindnyc.com` (✅ Available)
- AWS Amplify/Cognito authentication (✅ Working)
- HealthKit permissions (✅ Configured)
- Apple Watch for testing (✅ Available)

### Internal Prerequisites
- All compilation errors resolved (✅ Complete)
- Clean architecture in place (✅ Complete)
- UI components functional (✅ Complete)
- Test infrastructure ready (✅ Complete)

## Acceptance Testing

### User Acceptance Criteria
1. User opens app and sees real health data on dashboard
2. User can chat with AI and receive contextual health insights
3. User's Apple Watch data appears in app automatically
4. User sees PAT analysis results and trends
5. App works reliably without crashes or "not implemented" errors
6. Network failures are handled gracefully with retry options

### Technical Validation
1. All API endpoints return HTTP 200 with valid data
2. Authentication headers included in all requests
3. Background sync operates without user intervention
4. WebSocket maintains connection during chat sessions
5. Error states provide actionable user guidance
6. Performance metrics meet iOS app standards

This PRD provides the foundation for systematic transformation of the CLARITY iOS app from a non-functional prototype into a production-ready health application. 