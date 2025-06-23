# CLARITY Backend API Endpoints Documentation

**Base URL**: https://clarity.novamindnyc.com  
**Last Tested**: 2025-01-22

## Working Endpoints

### 1. Root & Health Check
- **GET /** - Returns API info (200 OK)
  ```json
  {"message":"CLARITY Digital Twin Platform API","version":"0.1.0","status":"operational"}
  ```
- **GET /health** - Health check (200 OK)
  ```json
  {"status":"healthy","version":"0.1.0"}
  ```

### 2. Authentication Endpoints
- **GET /api/v1/auth/me** - Returns 401 when not authenticated (working as expected)
- **POST /api/v1/auth/login** - Returns 422 when body is missing (working as expected)
- Auth endpoints appear to be properly implemented

## Broken/Non-Existent Endpoints

### 1. Insights Endpoints
- **GET /api/v1/insights** - Returns 405 Method Not Allowed (should be POST only)
- **POST /api/v1/insights** - Returns 401 without auth (working correctly)
- **POST /api/v1/insights/chat** - Returns 405 Method Not Allowed ❌ **BROKEN**
- **GET /api/v1/insights/alerts** - Returns 401 without auth (working correctly)

### 2. Health Data Endpoints
- **GET /api/v1/health-data** - Returns 401 without auth ✅ **WORKING**
- **POST /api/v1/healthkit** - Returns 401 without auth ✅ **WORKING**
- **POST /api/v1/healthkit/sync** - Returns 404 Not Found ❌ **DOESN'T EXIST**
- ~~GET /api/v1/health-data/metrics~~ - Wrong endpoint path
- ~~POST /api/v1/health-data/upload~~ - Wrong endpoint path

### 3. PAT Analysis Endpoints
- **POST /api/v1/pat-analysis/step-data** - Returns 404 Not Found ❌ **DOESN'T EXIST**
- **GET /api/v1/pat-analysis/health** - Returns 404 Not Found ❌ **DOESN'T EXIST**

## Key Findings

1. **Authentication Required**: Most endpoints properly return 401 when not authenticated
2. **Chat Endpoint Broken**: `/api/v1/insights/chat` returns 405, confirming our fix to use the insights generation endpoint was correct
3. **Health Data Endpoints Work**: The health data endpoints (`/api/v1/health-data` and `/api/v1/healthkit`) return 401, meaning they exist and require authentication
4. **PAT Analysis Missing**: All PAT analysis endpoints return 404, suggesting this feature isn't implemented on the backend
5. **Sync Endpoint Missing**: The `/api/v1/healthkit/sync` endpoint doesn't exist (404)

## Next Steps

1. ✅ We already fixed the chat to use insights generation endpoint
2. Need to investigate the correct health data upload endpoint format
3. PAT analysis features should be disabled in the UI until backend implements them
4. Need to test with authentication token to see which endpoints actually work

## Testing with Authentication

To properly test protected endpoints, we need:
1. A valid JWT token from AWS Cognito
2. Bearer token in Authorization header
3. Proper request bodies for POST endpoints

## Recommendations

1. **Health Data Sync**: The upload endpoint appears broken. We need to:
   - Check if there's an alternative endpoint
   - Verify the correct HTTP method
   - Test with proper authentication

2. **PAT Analysis**: Since these endpoints don't exist:
   - Hide or disable PAT analysis features in the app
   - Show "Coming Soon" message
   - Remove any automatic PAT analysis calls

3. **Chat Feature**: Our fix to use insights generation is correct since chat endpoint doesn't work

4. **Error Handling**: The app should gracefully handle these 405 and 404 errors