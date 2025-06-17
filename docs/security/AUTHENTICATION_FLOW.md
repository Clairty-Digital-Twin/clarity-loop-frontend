# AWS Amplify Authentication Flow

## Overview
CLARITY Loop uses AWS Amplify SDK for iOS to handle authentication through AWS Cognito. This provides a secure, scalable authentication system with built-in token management, email verification, and password reset capabilities.

## Configuration

### AWS Cognito Settings
```json
{
  "UserPoolId": "us-east-1_efXaR5EcP",
  "AppClientId": "7sm7ckrkovg78b03n1595euc71",
  "Region": "us-east-1",
  "authenticationFlowType": "USER_SRP_AUTH"
}
```

### Amplify Configuration
Located in `Resources/amplifyconfiguration.json`:
- **Authentication Flow**: USER_SRP_AUTH (Secure Remote Password)
- **Username Attributes**: Email
- **Sign-up Attributes**: Email (required)
- **Password Policy**: Minimum 8 characters

## Authentication Service Architecture

### Core Components

#### 1. AmplifyConfigurator
**Location**: `Core/Services/AmplifyConfigurator.swift`
- Singleton pattern for Amplify initialization
- Configures Auth category on app launch
- Loads configuration from `amplifyconfiguration.json`

#### 2. AuthService
**Location**: `Core/Services/AuthService.swift`
- Main authentication interface for the app
- Implements `AuthServiceProtocol`
- Handles all auth operations through Amplify

#### 3. AuthUser Model
**Location**: `Data/Models/AuthUser.swift`
- Represents authenticated user data
- Maps between Amplify user attributes and app models
- Stores user ID, email, and metadata

## Authentication Flows

### 1. User Registration
```swift
// Frontend Flow
1. User enters email and password in RegistrationView
2. RegistrationViewModel calls AuthService.signUp()
3. AuthService uses Amplify.Auth.signUp()
4. Cognito sends verification email
5. User redirected to EmailVerificationView
```

**Backend Sync**:
- After email verification, backend automatically creates DynamoDB user record
- User preferences initialized with defaults

### 2. Email Verification
```swift
// Verification Flow
1. User receives 6-digit code via email
2. EmailVerificationViewModel calls AuthService.confirmSignUp()
3. AuthService uses Amplify.Auth.confirmSignUp()
4. On success, user is automatically signed in
5. Backend sync triggered via /api/v1/auth/me
```

### 3. User Login
```swift
// Login Flow
1. User enters email and password in LoginView
2. LoginViewModel calls AuthService.signIn()
3. AuthService uses Amplify.Auth.signIn()
4. Cognito returns JWT tokens (handled by Amplify)
5. Tokens stored securely in iOS Keychain
6. AuthService.syncUserWithBackend() called
```

### 4. Token Management
**Automatic Token Handling**:
- Amplify manages token storage in iOS Keychain
- Access tokens auto-refresh when expired
- No manual token management needed

**Token Usage**:
```swift
// Getting current auth session
let session = try await Amplify.Auth.fetchAuthSession()
if let cognitoSession = session as? AuthCognitoTokensProvider {
    let idToken = try cognitoSession.getCognitoTokens().get().idToken
    // Use token for API calls
}
```

### 5. Password Reset
```swift
// Reset Flow
1. User requests reset via ForgotPasswordView
2. AuthService.resetPassword() called
3. Cognito sends reset code to email
4. User enters code and new password
5. AuthService.confirmResetPassword() completes reset
```

### 6. Logout
```swift
// Logout Flow
1. User taps logout in settings
2. AuthService.signOut() called
3. Amplify.Auth.signOut() clears tokens
4. User redirected to login screen
5. Local user data cleared
```

## Backend Integration

### API Authentication
All authenticated API calls include Cognito JWT token:
```swift
// In APIClient
private func authenticatedRequest() async throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    
    // Get token from AuthService
    if let token = await authService.currentAccessToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    return request
}
```

### Backend Middleware
The backend uses `CognitoAuthMiddleware` to:
1. Validate JWT tokens against Cognito
2. Extract user information from tokens
3. Auto-create/update DynamoDB user records
4. Populate `request.state.user` for authenticated routes

## Security Features

### 1. Secure Token Storage
- Tokens stored in iOS Keychain (encrypted)
- Managed entirely by Amplify SDK
- No tokens stored in UserDefaults or files

### 2. Biometric Authentication
- Optional Face ID/Touch ID for app access
- Implemented via `LocalAuthentication` framework
- Supplements Cognito authentication

### 3. Session Management
- Sessions expire based on Cognito configuration
- Amplify Hub monitors auth events
- Automatic redirect to login on session expiry

### 4. Network Security
- All API calls use HTTPS
- Certificate pinning available
- No sensitive data in URL parameters

## Error Handling

### Common Auth Errors
```swift
enum AuthError {
    case userNotFound
    case incorrectPassword
    case userNotConfirmed
    case codeMismatch
    case codeExpired
    case networkError
}
```

### Error Recovery
- Automatic retry for network errors
- Clear user messaging for auth failures
- Resend verification code option
- Password reset fallback

## Testing Authentication

### Development Testing
1. Use test Cognito user pool for development
2. Email verification codes logged in console (dev mode)
3. Test accounts with known passwords

### Unit Testing
- Mock `AuthServiceProtocol` for unit tests
- `DummyAuthService` for SwiftUI previews
- Test-specific Amplify configuration

### Integration Testing
- End-to-end auth flow tests
- Token refresh scenarios
- Error condition testing

## Monitoring & Analytics

### Auth Events
Amplify Hub broadcasts authentication events:
- `signedIn`
- `signedOut`
- `sessionExpired`
- `userDeleted`

### Metrics Tracking
- Login success/failure rates
- Registration conversion
- Password reset usage
- Session duration

## Best Practices

### 1. Token Handling
- Never log or store tokens in plain text
- Always use Amplify's token management
- Implement proper token refresh logic

### 2. Error Messages
- Don't reveal whether email exists
- Generic messages for security
- Specific messages for UX where safe

### 3. Session Management
- Clear local data on logout
- Handle session expiry gracefully
- Implement "Remember Me" carefully

### 4. Development
- Use separate Cognito pools for dev/prod
- Never commit AWS credentials
- Test auth flows thoroughly

## Migration Notes

### From Firebase to Amplify
1. No user data migration needed (new user pool)
2. Removed manual JWT handling
3. Simplified token refresh logic
4. Integrated email verification

### Key Differences
- No `TokenManager` class needed
- No manual Keychain operations
- Automatic token refresh
- Built-in email verification