# API Contracts

## Overview
This document defines the API contracts between the CLARITY Loop iOS frontend and the backend API hosted at `https://clarity.novamindnyc.com`.

## Base Configuration
- **Base URL**: `https://clarity.novamindnyc.com/api/v1`
- **Authentication**: Bearer token (AWS Cognito JWT)
- **Content-Type**: `application/json`
- **API Version**: v1

## Authentication Endpoints

### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securePassword123"
}

Response 200:
{
  "message": "User created successfully. Please check your email for verification code.",
  "userId": "cognito-user-id"
}
```

### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securePassword123"
}

Response 200:
{
  "user": {
    "id": "uuid",
    "displayName": "John Doe",
    "preferences": {
      "notifications_enabled": true,
      "health_sync_enabled": true,
      "biometric_enabled": false
    },
    "metadata": {
      "lastLoginAt": "2025-06-17T10:00:00Z",
      "createdAt": "2025-06-01T10:00:00Z"
    }
  },
  "tokens": {
    "accessToken": "cognito.jwt.access",
    "refreshToken": "cognito.jwt.refresh",
    "idToken": "cognito.jwt.id",
    "expiresIn": 3600
  }
}
```

### Confirm Email
```http
POST /api/v1/auth/confirm-email
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}

Response 200:
{
  "message": "Email confirmed successfully",
  "user": { /* User object */ }
}
```

### Get Current User
```http
GET /api/v1/auth/me
Authorization: Bearer <access_token>

Response 200:
{
  "id": "uuid",
  "email": "user@example.com",
  "displayName": "John Doe",
  "preferences": {
    "notifications_enabled": true,
    "health_sync_enabled": true,
    "biometric_enabled": false
  },
  "metadata": {
    "lastLoginAt": "2025-06-17T10:00:00Z",
    "createdAt": "2025-06-01T10:00:00Z"
  }
}
```

### Update User
```http
PUT /api/v1/auth/me
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "displayName": "Jane Doe",
  "preferences": {
    "notifications_enabled": false
  }
}

Response 200:
{
  "id": "uuid",
  "email": "user@example.com",
  "displayName": "Jane Doe",
  "preferences": { /* Updated preferences */ }
}
```

### Refresh Token
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refreshToken": "cognito.jwt.refresh"
}

Response 200:
{
  "accessToken": "new.cognito.jwt.access",
  "idToken": "new.cognito.jwt.id",
  "expiresIn": 3600
}
```

### Password Reset
```http
POST /api/v1/auth/forgot-password
Content-Type: application/json

{
  "email": "user@example.com"
}

Response 200:
{
  "message": "Password reset code sent to email"
}
```

```http
POST /api/v1/auth/reset-password
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newSecurePassword123"
}

Response 200:
{
  "message": "Password reset successfully"
}
```

## Health Data Endpoints

### Upload Health Data
```http
POST /api/v1/health-data
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "dataType": "heartRate",
  "value": 72,
  "unit": "bpm",
  "timestamp": "2025-06-17T10:00:00Z",
  "source": "AppleWatch",
  "metadata": {
    "device": "Apple Watch Series 9",
    "accuracy": "high"
  }
}

Response 200:
{
  "id": "health-data-uuid",
  "message": "Health data uploaded successfully"
}
```

### Get Health Data
```http
GET /api/v1/health-data?dataType=heartRate&startDate=2025-06-01&endDate=2025-06-17
Authorization: Bearer <access_token>

Response 200:
{
  "data": [
    {
      "id": "uuid",
      "dataType": "heartRate",
      "value": 72,
      "unit": "bpm",
      "timestamp": "2025-06-17T10:00:00Z",
      "source": "AppleWatch"
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "pageSize": 50
  }
}
```

## HealthKit Integration

### Bulk Upload HealthKit Data
```http
POST /api/v1/healthkit/bulk-upload
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "samples": [
    {
      "type": "HKQuantityTypeIdentifierHeartRate",
      "value": 72,
      "unit": "count/min",
      "startDate": "2025-06-17T10:00:00Z",
      "endDate": "2025-06-17T10:00:00Z",
      "sourceName": "Apple Watch",
      "sourceVersion": "10.1",
      "device": {
        "name": "Apple Watch",
        "manufacturer": "Apple Inc.",
        "model": "Watch9,1",
        "hardwareVersion": "1.0",
        "softwareVersion": "10.1"
      }
    }
  ]
}

Response 200:
{
  "processed": 1,
  "failed": 0,
  "errors": []
}
```

### Get HealthKit Sync Status
```http
GET /api/v1/healthkit/sync-status
Authorization: Bearer <access_token>

Response 200:
{
  "lastSyncDate": "2025-06-17T10:00:00Z",
  "syncedDataTypes": [
    "heartRate",
    "steps",
    "activeEnergy",
    "restingEnergy",
    "sleepAnalysis"
  ],
  "pendingSamples": 0
}
```

## PAT Analysis

### Submit PAT Assessment
```http
POST /api/v1/pat/assessment
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "responses": {
    "q1": 3,
    "q2": 2,
    "q3": 4,
    // ... all PAT questions
  },
  "completedAt": "2025-06-17T10:00:00Z"
}

Response 200:
{
  "id": "assessment-uuid",
  "score": 45,
  "riskLevel": "moderate",
  "recommendations": [
    "Consider talking to a mental health professional",
    "Practice stress reduction techniques"
  ]
}
```

### Get PAT History
```http
GET /api/v1/pat/history
Authorization: Bearer <access_token>

Response 200:
{
  "assessments": [
    {
      "id": "uuid",
      "completedAt": "2025-06-17T10:00:00Z",
      "score": 45,
      "riskLevel": "moderate"
    }
  ]
}
```

## AI Insights

### Generate Health Insights
```http
POST /api/v1/insights/generate
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "dataTypes": ["heartRate", "sleep", "activity"],
  "timeRange": {
    "start": "2025-06-01T00:00:00Z",
    "end": "2025-06-17T23:59:59Z"
  },
  "insightType": "weekly_summary"
}

Response 200:
{
  "id": "insight-uuid",
  "generatedAt": "2025-06-17T10:00:00Z",
  "insights": {
    "summary": "Your health metrics show...",
    "heartRate": {
      "average": 72,
      "trend": "stable",
      "analysis": "Your heart rate is within normal range..."
    },
    "recommendations": [
      "Maintain current activity levels",
      "Consider morning exercise for better sleep"
    ]
  }
}
```

### Get Insight History
```http
GET /api/v1/insights
Authorization: Bearer <access_token>

Response 200:
{
  "insights": [
    {
      "id": "uuid",
      "generatedAt": "2025-06-17T10:00:00Z",
      "type": "weekly_summary",
      "preview": "Your health metrics show improvement..."
    }
  ]
}
```

## WebSocket Communication

### Chat Connection
```websocket
WS /api/v1/ws/chat
Authorization: Bearer <access_token>

// Client message
{
  "type": "message",
  "content": "Tell me about my sleep patterns"
}

// Server response
{
  "type": "response",
  "content": "Based on your sleep data...",
  "timestamp": "2025-06-17T10:00:00Z"
}
```

## Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "AUTH_INVALID_TOKEN",
    "message": "Invalid or expired token",
    "details": {
      "field": "authorization",
      "reason": "Token expired"
    }
  },
  "timestamp": "2025-06-17T10:00:00Z"
}
```

### Common Error Codes
- `AUTH_INVALID_TOKEN` - Invalid or expired token
- `AUTH_USER_NOT_FOUND` - User does not exist
- `AUTH_INVALID_CREDENTIALS` - Wrong password
- `AUTH_USER_NOT_CONFIRMED` - Email not verified
- `VALIDATION_ERROR` - Request validation failed
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `INTERNAL_SERVER_ERROR` - Server error

## Rate Limiting
- **Default**: 100 requests per minute per user
- **Bulk uploads**: 10 requests per minute
- **AI insights**: 20 requests per hour

## Pagination
All list endpoints support pagination:
```
GET /api/v1/health-data?page=1&pageSize=50
```

Response includes:
```json
{
  "data": [...],
  "pagination": {
    "total": 1000,
    "page": 1,
    "pageSize": 50,
    "totalPages": 20
  }
}
```

## Data Types

### Health Data Types
- `heartRate` - Heart rate in bpm
- `steps` - Step count
- `activeEnergy` - Active calories burned
- `restingEnergy` - Resting calories burned
- `sleepAnalysis` - Sleep duration and quality
- `bloodOxygen` - SpO2 percentage
- `bodyTemperature` - Temperature in Celsius
- `respiratoryRate` - Breaths per minute

### Units
- Heart Rate: `bpm` (beats per minute)
- Energy: `kcal` (kilocalories)
- Distance: `m` (meters)
- Temperature: `degC` (degrees Celsius)
- Time: ISO 8601 format