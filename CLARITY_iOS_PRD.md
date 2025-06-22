# CLARITY iOS Frontend Production Readiness PRD

## Executive Summary
The CLARITY iOS app is currently non-functional as a backend wrapper due to critical API integration failures. All core features return "not implemented" errors, preventing production deployment. This PRD outlines the systematic fixes required to make the app a proper wrapper for the existing, fully-functional backend API.

## Problem Statement
- **Chat Feature**: Returns `APIError.notImplemented` instead of connecting to `/api/v1/insights/` and WebSocket endpoints
- **HealthKit Sync**: Apple Watch data not uploading to backend `/api/v1/healthkit/upload` endpoint
- **Dashboard Analytics**: Shows error states instead of fetching real data from `/api/v1/pat/` and `/api/v1/metrics/`
- **Authentication**: JWT tokens not properly included in API requests
- **Real-time Features**: No WebSocket connection to `wss://backend/api/v1/ws/`

## Backend API Reference
The backend provides fully implemented endpoints:
- `/api/v1/insights/` - Gemini AI chat functionality
- `/api/v1/ws/{room_id}` - Real-time WebSocket chat
- `/api/v1/healthkit/upload` - HealthKit data batch upload
- `/api/v1/health-data/` - Health data retrieval
- `/api/v1/pat/analysis/{user_id}` - PAT analysis results
- `/api/v1/metrics/` - Health metrics aggregation
- `/api/v1/auth/` - Authentication endpoints

## Technical Requirements

### 1. API Integration Layer (CRITICAL)
**Current State**: All methods in `BackendAPIClient.swift` return `APIError.notImplemented`
**Required**: Replace stub methods with real HTTP calls to backend endpoints
**Files**: `clarity-loop-frontend/Core/Networking/BackendAPIClient.swift`
**Success Criteria**: All API methods make actual HTTP requests and return real data

### 2. Request/Response Models
**Current State**: iOS models don't match backend schemas
**Required**: Create backend-matching DTOs with proper JSON serialization
**Files**: `clarity-loop-frontend/Data/DTOs/`
**Success Criteria**: Models serialize/deserialize correctly with backend API

### 3. Chat Feature Implementation
**Current State**: `ChatViewModel` calls non-existent methods
**Required**: 
- REST API integration with `/api/v1/insights/` for chat responses
- WebSocket connection to `wss://backend/api/v1/ws/{room_id}` for real-time chat
- Message persistence and history
**Files**: `clarity-loop-frontend/Features/Chat/ChatViewModel.swift`
**Success Criteria**: Users can chat with Gemini AI and receive real responses

### 4. HealthKit Backend Integration
**Current State**: HealthKit data stays local, no backend upload
**Required**:
- Batch upload to `/api/v1/healthkit/upload` endpoint
- Background sync with retry logic
- Apple Watch data capture and transmission
**Files**: `clarity-loop-frontend/Core/Services/HealthKitService.swift`
**Success Criteria**: Apple Watch data automatically syncs to backend

### 5. Dashboard Analytics
**Current State**: Shows "Oops, something went wrong" error state
**Required**:
- Fetch real data from `/api/v1/pat/analysis/{user_id}`
- Display health metrics from `/api/v1/metrics/`
- Show insight history from `/api/v1/insights/history/{user_id}`
**Files**: `clarity-loop-frontend/Features/Dashboard/DashboardViewModel.swift`
**Success Criteria**: Dashboard displays real analytics and insights

### 6. Authentication Headers
**Current State**: API calls missing Authorization headers
**Required**: Include JWT tokens from AWS Amplify in all API requests
**Files**: `clarity-loop-frontend/Core/Networking/BackendAPIClient.swift`
**Success Criteria**: All API calls include proper Bearer token authentication

### 7. Error Handling & UX
**Current State**: Poor error states and no retry logic
**Required**: Comprehensive error handling with user-friendly messages
**Files**: Various ViewModels and Views
**Success Criteria**: Users see helpful error messages and retry options

### 8. Real-time Features
**Current State**: No WebSocket implementation
**Required**: WebSocket manager for real-time chat and health updates
**Files**: New `WebSocketManager.swift` class
**Success Criteria**: Real-time chat with typing indicators

## Implementation Strategy

### Phase 1: API Foundation (2-3 days)
1. Replace all `APIError.notImplemented` methods with real HTTP calls
2. Create backend-matching request/response models
3. Implement authentication headers in all requests
4. Test endpoints with backend integration

### Phase 2: Core Features (3-4 days)
1. Fix Chat feature with REST API and WebSocket
2. Implement HealthKit batch upload to backend
3. Connect Dashboard to real backend analytics
4. Add comprehensive error handling

### Phase 3: Testing & Polish (2-3 days)
1. End-to-end testing with real Apple Watch data
2. Performance optimization and caching
3. Error state UX improvements
4. Production deployment preparation

## Success Metrics
- ✅ Chat with Gemini AI working end-to-end
- ✅ Apple Watch health data syncing automatically
- ✅ Dashboard showing real analytics from backend
- ✅ All authentication flows working
- ✅ Error states properly handled
- ✅ Real-time chat with typing indicators

## Technical Constraints
- Must maintain HIPAA compliance
- iOS 18.4+ compatibility required
- SwiftUI + Clean Architecture patterns
- AWS Amplify/Cognito authentication
- Backend URL: `https://clarity.novamindnyc.com`

## Acceptance Criteria
1. User can chat with AI and receive health-aware responses
2. Apple Watch data automatically syncs in background
3. Dashboard displays real PAT analysis and metrics
4. All features work without "not implemented" errors
5. App handles network failures gracefully
6. Authentication works seamlessly across all features

## Risk Mitigation
- **Backend Availability**: Backend is stable and fully functional
- **API Documentation**: Backend code provides clear endpoint specifications
- **Authentication**: AWS Amplify integration already working
- **Testing**: Comprehensive test suite exists, needs integration testing

## Timeline
**Total Estimated Time**: 7-10 days
**Target Completion**: Within 2 weeks
**Critical Path**: API integration layer must be completed first

## Dependencies
- Backend API at `https://clarity.novamindnyc.com` (✅ Available)
- AWS Amplify/Cognito authentication (✅ Working)
- HealthKit permissions (✅ Configured)
- Apple Watch for testing (✅ Available)

This PRD provides the foundation for systematic implementation of a fully functional CLARITY iOS app that properly wraps the backend API. 