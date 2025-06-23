# CLARITY API Quick Reference

## Base URL
`https://clarity.novamindnyc.com`

## Authentication
All endpoints require Bearer token in Authorization header except where noted.

## Working Endpoints

### Auth
- `POST /api/v1/auth/register` - User registration (no auth required)
- `POST /api/v1/auth/login` - User login (no auth required)  
- `GET /api/v1/auth/me` - Get current user
- `POST /api/v1/auth/logout` - Logout

### Health Data
- `GET /api/v1/health-data` - Get health metrics (with pagination)
- `POST /api/v1/healthkit` - Upload health data from HealthKit

### Insights
- `POST /api/v1/insights` - Generate AI insights
- `GET /api/v1/insights/history/{userId}` - Get insight history
- `GET /api/v1/insights/{id}` - Get specific insight
- `GET /api/v1/insights/alerts` - Service status

## Non-Working Endpoints
- ❌ `POST /api/v1/insights/chat` - Use insights generation instead
- ❌ `POST /api/v1/healthkit/sync` - Not implemented
- ❌ All PAT analysis endpoints - Not implemented

## Request/Response Format
All requests and responses use JSON with snake_case field names.

## Error Responses
```json
{
  "detail": "Error message"
}
```

## Authentication Header
```
Authorization: Bearer <JWT_TOKEN>
```