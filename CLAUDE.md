# CLARITY Pulse iOS Health App - Claude Guidelines

## Project Overview
CLARITY Pulse is a HIPAA-compliant iOS health tracking application built with SwiftUI, following MVVM + Clean Architecture principles. The app integrates with HealthKit, AWS Amplify + Cognito, and provides secure biometric authentication for sensitive health data management.

## Architecture Requirements

### Design Patterns
- **MVVM + Clean Architecture** with Protocol-Oriented Design
- **SwiftUI + iOS 17's @Observable** for reactive UI
- **Environment-based Dependency Injection** for lightweight IoC
- **Repository Pattern** for data abstraction
- **ViewState<T>** pattern for async operation handling

### Layer Structure
```
UI Layer         → SwiftUI Views + ViewModels
Domain Layer     → Use Cases + Domain Models + Repository Protocols  
Data Layer       → Repositories + Services + DTOs
Core Layer       → Networking + Persistence + Utilities
```

## Code Standards

### Access Control (CRITICAL)
- **PRIVATE by default**: All implementation details should be `private`
- **INTERNAL**: Module-internal access for shared components
- **PUBLIC**: Only for protocols and essential interfaces
- **NO public classes/structs** unless absolutely necessary for external access

### Security & HIPAA Compliance
- No logging of sensitive health information
- All health data handling must maintain HIPAA compliance
- Secure data transmission only (HTTPS)
- User consent required for all HealthKit access
- Biometric authentication for sensitive operations

### SwiftUI Best Practices
- Use `@Observable` for ViewModels (iOS 17+)
- Environment injection over singletons
- Prefer composition over inheritance
- Keep Views lightweight - logic in ViewModels
- Use `ViewState<T>` for async operations

### Testing Standards
- Protocol-based mocks for all major services
- Mock all external dependencies (AWS Amplify, HealthKit, API)
- Use Environment injection for test doubles
- Test ViewModels in isolation
- Integration tests for critical health data flows
- **Current Status**: 489 tests passing (98.9% success rate)

### Naming Conventions
- **ViewModels**: `[Feature]ViewModel` (e.g., `AuthViewModel`)
- **Services**: `[Purpose]Service` (e.g., `HealthKitService`)
- **Repositories**: `[Domain]Repository` (e.g., `RemoteHealthDataRepository`)
- **DTOs**: Descriptive names ending in `DTO`

### File Organization
```
clarity-loop-frontend/
├── Application/         # App lifecycle
├── Core/               # Infrastructure layer
├── Data/               # Data layer (DTOs, Models, Repositories)
├── Domain/             # Business logic layer
├── Features/           # Feature modules (MVVM)
└── UI/                 # Shared UI components
```

## Framework Integration

### AWS Amplify
- Authentication handled by AWS Cognito via Amplify
- JWT tokens auto-refreshed by Amplify SDK
- API calls use Bearer token authentication
- Configuration in `amplifyconfiguration.json`

### HealthKit
- All HealthKit operations must be async and properly handled
- User consent required for all data access
- Error handling for denied permissions
- Background sync capabilities

### SwiftData
- Primary persistence layer (iOS 17+)
- Use with iOS file protection for security
- Proper entity relationships and constraints

## When Creating PRs

### Implementation Requirements
1. Follow MVVM + Clean Architecture patterns
2. Implement proper error handling with ViewState<T>
3. Add comprehensive unit tests for new functionality
4. Ensure HIPAA compliance for health data operations
5. Use proper access control (private by default)
6. Follow SwiftUI performance best practices

### Security Checklist
- [ ] No sensitive data in logs
- [ ] Proper error handling without exposing internals
- [ ] Biometric authentication for sensitive operations
- [ ] HTTPS-only data transmission
- [ ] Proper HealthKit permission handling

### Testing Checklist
- [ ] Unit tests for ViewModels
- [ ] Mock implementations for external services
- [ ] Integration tests for critical flows
- [ ] UI tests for key user journeys
- [ ] Performance tests for memory leaks

## Common Issues to Avoid

1. **Memory Leaks**: Always use weak references in closures
2. **UI on Background Thread**: Ensure UI updates on main thread
3. **Force Unwrapping**: Use proper optional handling
4. **Hardcoded Strings**: Use localized strings
5. **Missing Error Handling**: Every async operation needs error handling

## Review Focus Areas

When reviewing code, prioritize:
1. HIPAA compliance and security
2. Architecture adherence
3. Memory management
4. Test coverage
5. Performance implications
6. Accessibility compliance

## Build & Test Commands

```bash
# Build
xcodebuild -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontend -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test
xcodebuild test -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontendTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Current Status
- ✅ Build: Successful
- ✅ Tests: 489 passing (98.9% success rate)
- ✅ Architecture: MVVM + Clean Architecture implemented
- ✅ AWS Integration: Configured and working
- ⚠️ Simulator: SpringBoard crash issues (being addressed)

Remember: This is a production health application handling sensitive user data. Always prioritize security, privacy, and HIPAA compliance in all development decisions.

---

*Last updated: 2025-06-17*
