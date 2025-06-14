//
//  EnvironmentKeys.swift
//  clarity-loop-frontend
//
//  Created by Claude on 5/10/2025.
//

import Foundation
import SwiftUI

// MARK: - Shared Token Provider

/// Shared token provider for default environment values
/// Returns nil to avoid early TokenManager access during environment setup
private let defaultTokenProvider: () async -> String? = {
    print("⚠️ Default environment: Using fallback tokenProvider (no authentication)")
    return nil // Don't access TokenManager.shared during environment setup!
}

// MARK: - AuthService

/// The key for accessing the `AuthServiceProtocol` in the SwiftUI Environment.
private struct AuthServiceKey: EnvironmentKey {
    typealias Value = AuthServiceProtocol?
    static let defaultValue: AuthServiceProtocol? = nil
}

/// The key for accessing the `AuthViewModel` in the SwiftUI Environment.
/// Note: This is kept for backwards compatibility, but the app uses the new iOS 17+ @Environment(Type.self) pattern
struct AuthViewModelKey: EnvironmentKey {
    typealias Value = AuthViewModel?
    static var defaultValue: AuthViewModel?
}

private struct APIClientKey: EnvironmentKey {
    typealias Value = APIClientProtocol?
    static let defaultValue: APIClientProtocol? = nil
}

// MARK: - Repository Protocols

private struct HealthDataRepositoryKey: EnvironmentKey {
    typealias Value = HealthDataRepositoryProtocol?
    static let defaultValue: HealthDataRepositoryProtocol? = nil
}

private struct InsightsRepositoryKey: EnvironmentKey {
    typealias Value = InsightsRepositoryProtocol?
    static let defaultValue: InsightsRepositoryProtocol? = nil
}

private struct UserRepositoryKey: EnvironmentKey {
    typealias Value = UserRepositoryProtocol?
    static let defaultValue: UserRepositoryProtocol? = nil
}

private struct HealthKitServiceKey: EnvironmentKey {
    typealias Value = HealthKitServiceProtocol?
    static let defaultValue: HealthKitServiceProtocol? = nil
}

// Security services will be added later when protocols are defined

extension EnvironmentValues {
    /// Provides access to the `AuthService` throughout the SwiftUI environment.
    var authService: AuthServiceProtocol {
        get { 
            if let service = self[AuthServiceKey.self] {
                return service
            } else {
                print("🚨 AuthService accessed before injection!")
                print("🔍 Call stack:")
                Thread.callStackSymbols.prefix(10).forEach { print("   \($0)") }
                
                fatalError("AuthService accessed before injection - see call stack above for culprit")
            }
        }
        set { self[AuthServiceKey.self] = newValue }
    }
    
    /// Provides access to the `AuthViewModel` throughout the SwiftUI environment.
    var authViewModel: AuthViewModel? {
        get { self[AuthViewModelKey.self] }
        set { self[AuthViewModelKey.self] = newValue }
    }
    
    var healthDataRepository: HealthDataRepositoryProtocol {
        get { 
            guard let repo = self[HealthDataRepositoryKey.self] else {
                fatalError("HealthDataRepository must be injected")
            }
            return repo
        }
        set { self[HealthDataRepositoryKey.self] = newValue }
    }
    
    var insightsRepository: InsightsRepositoryProtocol {
        get { 
            guard let repo = self[InsightsRepositoryKey.self] else {
                fatalError("InsightsRepository must be injected")
            }
            return repo
        }
        set { self[InsightsRepositoryKey.self] = newValue }
    }
    
    var userRepository: UserRepositoryProtocol {
        get { 
            guard let repo = self[UserRepositoryKey.self] else {
                fatalError("UserRepository must be injected")
            }
            return repo
        }
        set { self[UserRepositoryKey.self] = newValue }
    }
    
    var healthKitService: HealthKitServiceProtocol {
        get { 
            guard let service = self[HealthKitServiceKey.self] else {
                fatalError("HealthKitService must be injected")
            }
            return service
        }
        set { self[HealthKitServiceKey.self] = newValue }
    }
    
    var apiClient: APIClientProtocol {
        get { 
            guard let client = self[APIClientKey.self] else {
                fatalError("APIClient must be injected")
            }
            return client
        }
        set { self[APIClientKey.self] = newValue }
    }
}

// Default values are provided above for each environment key
// These will be used in previews and when services aren't explicitly injected

// NOTE: Add other service keys here as needed (e.g., for HealthKit, Networking, etc.)