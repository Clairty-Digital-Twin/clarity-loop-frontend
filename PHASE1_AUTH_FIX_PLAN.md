# Phase 1: Authentication Fix Implementation Plan

## Problem Summary
Users can login via AWS Cognito but the app fails to sync with backend, resulting in no user data loading and "Loading user..." shown forever.

## Root Causes
1. `AuthService.syncUserWithBackend()` sends empty password to backend
2. Backend expects password validation, not Cognito token validation  
3. No proper user data caching after login
4. Settings page shows hardcoded "Loading user..." string

## Fix Implementation Steps

### Step 1: Remove Backend Sync Requirement
**File**: `/Core/Services/AuthService.swift`

The current flow is:
1. User logs in with Cognito ✅
2. App tries to sync with backend ❌ (sends empty password)
3. Backend rejects request ❌
4. No user data loads ❌

**Fix**: Remove the backend sync entirely and use Cognito as the source of truth.

```swift
// Line 276 - DELETE THIS METHOD
private func syncUserWithBackend(email: String) async throws -> UserSessionResponseDTO

// Line 342-350 - REPLACE with Cognito-only flow
if signInResult.isSignedIn {
    // Get user info from Cognito attributes
    let attributes = try await Amplify.Auth.fetchUserAttributes()
    let user = createUserFromCognitoAttributes(attributes)
    
    // Update auth state
    _currentUser = user
    authStateContinuation?.yield(user)
    
    return user.toSessionResponse()
}
```

### Step 2: Create User from Cognito Attributes
**File**: `/Core/Services/AuthService.swift`

Add method to create user from Cognito data:

```swift
private func createUserFromCognitoAttributes(_ attributes: [AuthUserAttribute]) -> AuthUser {
    var email = ""
    var name = ""
    var userId = ""
    
    for attribute in attributes {
        switch attribute.key {
        case .email:
            email = attribute.value
        case .name:
            name = attribute.value
        case .sub:
            userId = attribute.value
        default:
            break
        }
    }
    
    return AuthUser(
        id: userId,
        email: email,
        fullName: name,
        isEmailVerified: true
    )
}
```

### Step 3: Fix Settings View Model
**File**: `/Features/Settings/SettingsViewModel.swift`

Replace hardcoded "Loading user..." with actual data:

```swift
// Line 38-42 - REPLACE computed property with @Published property
@Published var currentUser: String = ""
@Published var isLoadingUser = true

// Line 56-58 - UPDATE loadUserProfile
func loadUserProfile() async {
    isLoadingUser = true
    if let user = await authService.currentUser {
        currentUser = user.email
        email = user.email
        // Parse name if available
        if let fullName = user.fullName {
            let names = fullName.split(separator: " ")
            firstName = String(names.first ?? "")
            lastName = names.dropFirst().joined(separator: " ")
        }
    } else {
        currentUser = "Not logged in"
    }
    isLoadingUser = false
}
```

### Step 4: Update Settings View
**File**: `/Features/Settings/SettingsView.swift`

Show loading state properly:

```swift
// Line 58 - UPDATE the profile display
if viewModel.isLoadingUser {
    ProgressView()
        .padding(.vertical, 8)
} else {
    VStack(alignment: .leading, spacing: 4) {
        Text(viewModel.currentUser)
            .font(.headline)
        Text("Tap to edit profile")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

### Step 5: Add User Data Persistence
**File**: Create `/Core/Services/UserDataService.swift`

```swift
import SwiftData
import Foundation

@MainActor
final class UserDataService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveUser(_ user: AuthUser) async throws {
        let userModel = UserProfileModel(
            userId: user.id,
            email: user.email,
            displayName: user.fullName ?? user.email,
            avatarUrl: nil,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        modelContext.insert(userModel)
        try modelContext.save()
    }
    
    func getUser(id: String) async throws -> UserProfileModel? {
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { $0.userId == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
```

### Step 6: Fix getCurrentUser Implementation
**File**: `/Core/Services/AuthService.swift`

Update to use cached data when offline:

```swift
var currentUser: AuthUser? {
    get async {
        // Try Amplify first
        do {
            let user = try await Amplify.Auth.getCurrentUser()
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            return createUserFromCognitoAttributes(attributes)
        } catch {
            // Fallback to cached user
            return _currentUser
        }
    }
}
```

### Step 7: Remove Backend User Endpoints
**File**: `/Core/Networking/BackendAPIClient.swift`

Comment out or remove backend-dependent methods:
- `syncUserWithBackend`
- Backend-specific user fetch calls

## Testing Plan

1. **Test Fresh Login**
   - Clear app data
   - Login with Cognito credentials
   - Verify user email shows in Settings
   - Verify no "Loading user..." message

2. **Test Offline Mode**
   - Login while online
   - Go offline
   - Kill and restart app
   - Verify cached user data loads

3. **Test Token Refresh**
   - Login and wait for token expiry
   - Verify auto-refresh works
   - Verify user stays logged in

4. **Test Logout**
   - Logout from Settings
   - Verify all user data cleared
   - Verify returns to login screen

## Success Criteria
- [ ] User can login and see their email in Settings
- [ ] No "Loading user..." shown after login
- [ ] User data persists across app restarts
- [ ] Logout clears all user data
- [ ] Works offline with cached data

## Estimated Time: 1 Day

## Next Phase
Once auth works, move to Phase 2: Backend Integration Fixes

---

*Update this document with any issues found during implementation*