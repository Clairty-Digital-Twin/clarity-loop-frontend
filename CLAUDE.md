# CLAUDE.md - Project State Documentation

## Current State (Last Updated: 2025-06-16)

### Overview
The CLARITY Loop Frontend is an iOS app built with SwiftUI that provides health tracking and insights. The project has been updated to use AWS Amplify for authentication instead of manual JWT/Keychain management.

### Recent Work Completed

#### AWS Amplify Authentication Integration
- Integrated AWS Amplify Swift SDK (version 2.48.1) for authentication
- Created `AmplifyConfigurator.swift` for centralized Amplify initialization
- Added `amplifyconfiguration.json` with actual AWS Cognito configuration:
  - User Pool ID: `us-east-1_efXaR5EcP`
  - App Client ID: `7sm7ckrkovg78b03n1595euc71`
  - Region: `us-east-1`
- Completely refactored `AuthService.swift` to use Amplify Auth instead of manual JWT handling
- Updated `clarity_loop_frontendApp.swift` to initialize Amplify on app launch
- Modified token provider to use Amplify's secure token management
- Updated all DTOs to match new backend contract structure:
  - `UserSessionResponseDTO` now uses new structure with `id`, `displayName`, `preferences`, and `metadata`
  - Updated `BackendContractAdapter` to handle new DTO structure
  - Fixed `UserProfile` model to work with new DTOs
- Updated test mocks (`MockAuthService`, `CorrectMockAPIClient`) to use new DTO structure

#### Build and Test Status
- **Build**: ✅ Successfully builds with no warnings
- **Tests**: ⚠️ Tests build but crash during runtime due to Amplify initialization in test environment
- **SwiftFormat**: ✅ No formatting issues
- **SwiftLint**: ✅ No linting issues

### Key Commands for Development

```bash
# Build the app (using project file now, not workspace)
xcodebuild -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontend -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests (currently failing due to Amplify initialization)
xcodebuild -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontend -destination 'platform=iOS Simulator,name=iPhone 16' test

# Format code
mint run swiftformat@0.51.15 .

# Lint code
mint run swiftlint

# Clear derived data (if build cache issues)
rm -rf ~/Library/Developer/Xcode/DerivedData/clarity-loop-frontend-*
```

### Project Structure

```
clarity-loop-frontend/
├── Resources/
│   └── amplifyconfiguration.json (AWS Cognito configuration)
├── Core/
│   ├── Architecture/
│   │   └── EnvironmentKeys.swift (contains DummyAuthService with Amplify compatibility)
│   ├── Services/
│   │   ├── AmplifyConfigurator.swift (new - Amplify initialization)
│   │   └── AuthService.swift (refactored to use Amplify Auth)
│   └── Adapters/
│       └── BackendContractAdapter.swift (updated for new DTOs)
├── Data/
│   ├── DTOs/
│   │   ├── AuthLoginDTOs.swift (updated with new response structure)
│   │   └── UserSessionResponseDTO+AuthUser.swift (updated mapping)
│   └── Models/
│       └── UserProfile.swift (updated to work with new DTOs)
├── Features/
│   └── Authentication/
│       ├── EmailVerificationView.swift
│       ├── EmailVerificationViewModel.swift (uses Amplify Auth for verification)
│       ├── RegistrationView.swift
│       └── RegistrationViewModel.swift
└── Tests/
    └── Mocks/
        ├── MockAuthService.swift (updated with new DTO structure)
        └── CorrectMockAPIClient.swift (updated with new DTO structure)
```

### Dependency Management

**Package Dependencies** (via Swift Package Manager):
- AWS Amplify: 2.48.1
- AWS SDK Swift: 1.2.59
- AWS CRT Swift: 0.48.0
- SQLite.swift: 0.15.3
- Smithy Swift: 0.125.0
- Swift Log: 1.6.3

**Tool Dependencies** (via Mint):
- SwiftFormat: 0.51.15 (pinned version)
- SwiftLint: latest

### AWS Amplify Configuration

The app now uses AWS Amplify for authentication with the following configuration:
- **Authentication Flow**: USER_SRP_AUTH
- **Username Attributes**: Email
- **Sign-up Attributes**: Email
- **Password Policy**: Minimum 8 characters

### Key Changes from Previous Implementation

1. **Token Management**: No longer using `TokenManager` or Keychain directly - Amplify handles secure token storage
2. **Authentication Flow**: Using Amplify's built-in authentication methods instead of direct API calls
3. **Session Management**: Amplify Hub events are used to monitor auth state changes
4. **Email Verification**: Integrated with Amplify's `confirmSignUp` method

### Known Issues and Next Steps

1. **Test Environment**: Tests crash because Amplify tries to initialize during test runs. Need to:
   - Add test-specific configuration
   - Mock Amplify services for unit tests
   - Consider using a test-specific `amplifyconfiguration.json`

2. **Backend Sync**: The `syncUserWithBackend` method in AuthService needs the backend to handle Cognito-authenticated users properly

3. **Error Handling**: Some Amplify-specific errors need better mapping to user-friendly messages

### Testing Authentication Flow

To test the Amplify authentication flow:
1. Build and run the app in simulator
2. Navigate to registration
3. Register with a valid email - Amplify will handle sending verification email via Cognito
4. Check email for verification code
5. Enter code in the email verification view
6. Upon successful verification, user is automatically signed in

### Notes for Future Development

- Amplify configuration is loaded from `amplifyconfiguration.json` in the app bundle
- The app uses Amplify's secure token storage - no manual keychain access needed
- Hub events are used to monitor authentication state changes
- All authentication operations are now async/await based
- The backend should validate Cognito tokens instead of managing its own JWT tokens