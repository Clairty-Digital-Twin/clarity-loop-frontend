# CLAUDE.md - Project State Documentation

## Current State (Last Updated: 2025-06-15)

### Overview
The CLARITY Loop Frontend is an iOS app built with SwiftUI that provides health tracking and insights. The project recently implemented email verification functionality to handle backend requirements for user registration.

### Recent Work Completed

#### Email Verification Implementation
- Created `EmailVerificationView.swift` and `EmailVerificationViewModel.swift` for 6-digit OTP verification
- Updated `AuthService` with email verification methods (`verifyEmail` and `resendVerificationEmail`)
- Modified `RegistrationViewModel` to handle 500 error as successful registration needing verification
- Added navigation flow from registration to email verification

#### SwiftFormat Configuration Fix
- Fixed deprecated SwiftFormat options in `.swiftformat` file
- Installed SwiftFormat 0.51.15 via Mint to ensure compatibility
- Updated configuration syntax from deprecated format to new format:
  - Changed `--sortedimports` to `--enable sortedImports`
  - Changed `--importgrouping` to `--enable sortImports`
  - Updated other deprecated options

#### Build and Test Status
- **Build**: ✅ Successfully builds with no warnings
- **Tests**: ✅ All tests pass (18 tests, 0 failures)
- **SwiftFormat**: ✅ No formatting issues
- **SwiftLint**: ✅ No linting issues

### Key Commands for Development

```bash
# Build the app
xcodebuild -workspace clarity-loop-frontend.xcworkspace -scheme clarity-loop-frontend -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -workspace clarity-loop-frontend.xcworkspace -scheme clarity-loop-frontend -destination 'platform=iOS Simulator,name=iPhone 16' test

# Format code
mint run swiftformat@0.51.15 .

# Lint code
mint run swiftlint
```

### Project Structure

```
clarity-loop-frontend/
├── Core/
│   ├── Architecture/
│   │   └── EnvironmentKeys.swift (contains DummyAuthService with email verification methods)
│   ├── Services/
│   │   └── AuthService.swift (implements email verification)
│   └── ...
├── Features/
│   └── Authentication/
│       ├── EmailVerificationView.swift (new)
│       ├── EmailVerificationViewModel.swift (new)
│       ├── RegistrationView.swift (updated with navigation)
│       └── RegistrationViewModel.swift (handles 500 error)
└── Tests/
    └── Mocks/
        ├── DummyAuthService.swift (updated with email verification)
        └── MockAuthService.swift (updated with email verification)
```

### Dependency Management

**IMPORTANT**: SwiftFormat must be pinned to version 0.51.15 to avoid compatibility issues.

To install dependencies:
```bash
# Install Mint (if not already installed)
brew install mint

# Install SwiftFormat 0.51.15
mint install nicklockwood/SwiftFormat@0.51.15

# Install SwiftLint
mint install realm/SwiftLint
```

### Known Issues and Workarounds

1. **Backend 500 Error**: The backend currently returns a 500 error when email verification is required after registration. The frontend treats this as a successful registration that needs email verification.

2. **SwiftFormat Version**: Must use version 0.51.15. Newer versions have breaking changes in configuration syntax.

### Next Steps

1. Create a Mintfile to pin dependency versions
2. Test email verification flow end-to-end once backend is fixed
3. Consider adding proper error handling for various backend response codes

### Testing Email Verification

To test the email verification flow:
1. Run the app in simulator
2. Navigate to registration
3. Fill in all fields and register
4. The app should navigate to email verification view when backend returns 500
5. Enter 6-digit code to verify email
6. Upon successful verification, user is logged in automatically

### Notes for Future Development

- The email verification flow stores the password temporarily to auto-login after verification
- OTP fields auto-advance and support backspace navigation
- Resend code has a 60-second cooldown
- All test mocks have been updated to support the new email verification methods