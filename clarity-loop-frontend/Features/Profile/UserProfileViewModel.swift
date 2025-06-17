import Foundation
import Observation
import SwiftData
import PhotosUI
import SwiftUI
import UIKit

@Observable
@MainActor
final class UserProfileViewModel: BaseViewModel {
    // MARK: - Properties
    
    private(set) var profileState: ViewState<UserProfileModel> = .idle
    private(set) var updateState: ViewState<Bool> = .idle
    private(set) var imageSelection: PhotosPickerItem?
    private(set) var selectedImage: UIImage?
    
    // MARK: - Dependencies
    
    private let userProfileRepository: UserProfileRepository
    private let authService: AuthServiceProtocol
    private let apiClient: APIClientProtocol
    
    // MARK: - Computed Properties
    
    var profile: UserProfileModel? {
        profileState.value
    }
    
    var isProfileComplete: Bool {
        guard let profile = profile else { return false }
        return !profile.displayName.isEmpty &&
               profile.dateOfBirth != nil &&
               profile.heightCm != nil &&
               profile.weightKg != nil
    }
    
    var profileCompletionPercentage: Double {
        guard let profile = profile else { return 0 }
        
        var completedFields = 0
        let totalFields = 7
        
        if !profile.displayName.isEmpty { completedFields += 1 }
        if profile.dateOfBirth != nil { completedFields += 1 }
        if profile.heightCm != nil { completedFields += 1 }
        if profile.weightKg != nil { completedFields += 1 }
        if profile.activityLevel != nil { completedFields += 1 }
        if profile.healthGoals != nil { completedFields += 1 }
        if profile.medicalConditions != nil { completedFields += 1 }
        
        return Double(completedFields) / Double(totalFields)
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        userProfileRepository: UserProfileRepository,
        authService: AuthServiceProtocol,
        apiClient: APIClientProtocol
    ) {
        self.userProfileRepository = userProfileRepository
        self.authService = authService
        self.apiClient = apiClient
        super.init(modelContext: modelContext)
    }
    
    // MARK: - Public Methods
    
    func loadProfile() async {
        profileState = .loading
        
        do {
            // Try to load from local storage first
            if let userId = await authService.currentUser?.id,
               let localProfile = try await userProfileRepository.fetchByUserId(userId) {
                profileState = .loaded(localProfile)
                
                // Sync with backend in background
                Task {
                    await syncProfile()
                }
            } else {
                // No local profile, fetch from backend
                await fetchProfileFromBackend()
            }
        } catch {
            profileState = .error(error)
            handle(error: error)
        }
    }
    
    func updateProfile(
        displayName: String? = nil,
        dateOfBirth: Date? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        activityLevel: ActivityLevel? = nil,
        healthGoals: String? = nil,
        medicalConditions: String? = nil
    ) async {
        guard var profile = profile else { return }
        
        updateState = .loading
        
        // Update fields
        if let displayName = displayName { profile.displayName = displayName }
        if let dateOfBirth = dateOfBirth { profile.dateOfBirth = dateOfBirth }
        if let heightCm = heightCm { profile.heightCm = heightCm }
        if let weightKg = weightKg { profile.weightKg = weightKg }
        if let activityLevel = activityLevel { profile.activityLevel = activityLevel }
        if let healthGoals = healthGoals { profile.healthGoals = healthGoals }
        if let medicalConditions = medicalConditions { profile.medicalConditions = medicalConditions }
        
        profile.lastModified = Date()
        
        do {
            // Save locally
            try await userProfileRepository.update(profile)
            profileState = .loaded(profile)
            
            // Sync with backend
            try await syncProfileUpdate(profile)
            updateState = .loaded(true)
        } catch {
            updateState = .error(error)
            handle(error: error)
        }
    }
    
    func updateProfileImage() async {
        guard let imageSelection = imageSelection else { return }
        
        do {
            if let data = try await imageSelection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
                
                // TODO: Upload image to storage service
                // For now, we'll just store it locally
                if var profile = profile {
                    profile.profileImageUrl = "local://\(UUID().uuidString)"
                    profile.lastModified = Date()
                    try await userProfileRepository.update(profile)
                    profileState = .loaded(profile)
                }
            }
        } catch {
            handle(error: error)
        }
    }
    
    func deleteAccount() async {
        guard let profile = profile else { return }
        
        do {
            // Delete from backend first
            // TODO: Implement account deletion API
            
            // Delete local data
            try await userProfileRepository.delete(profile)
            
            // Sign out
            await authService.signOut()
        } catch {
            handle(error: error)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchProfileFromBackend() async {
        do {
            guard let userId = await authService.currentUser?.id else {
                throw ProfileError.notAuthenticated
            }
            
            // TODO: Replace with actual API call when endpoint is ready
            // let response = try await apiClient.getUserProfile(userId: userId)
            
            // For now, create a default profile
            let profile = UserProfileModel()
            profile.userId = userId
            profile.email = await authService.currentUser?.email ?? ""
            profile.displayName = await authService.currentUser?.displayName ?? ""
            
            try await userProfileRepository.create(profile)
            profileState = .loaded(profile)
        } catch {
            profileState = .error(error)
            handle(error: error)
        }
    }
    
    private func syncProfile() async {
        do {
            try await userProfileRepository.sync()
        } catch {
            // Don't update UI state for background sync errors
            print("Profile sync error: \(error)")
        }
    }
    
    private func syncProfileUpdate(_ profile: UserProfileModel) async throws {
        // TODO: Implement actual API call
        // let updateRequest = UpdateUserProfileRequest(...)
        // try await apiClient.updateUserProfile(userId: profile.userId, request: updateRequest)
        
        // Mark as synced
        profile.syncStatus = .synced
        try await userProfileRepository.update(profile)
    }
}

// MARK: - Supporting Types

enum ProfileError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to access your profile"
        case .profileNotFound:
            return "Profile not found"
        case .updateFailed:
            return "Failed to update profile"
        }
    }
}

enum ActivityLevel: String, CaseIterable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extremelyActive = "Extremely Active"
    
    var description: String {
        switch self {
        case .sedentary:
            return "Little or no exercise"
        case .lightlyActive:
            return "Exercise 1-3 days/week"
        case .moderatelyActive:
            return "Exercise 3-5 days/week"
        case .veryActive:
            return "Exercise 6-7 days/week"
        case .extremelyActive:
            return "Very hard exercise daily"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}