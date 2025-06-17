@testable import clarity_loop_frontend
import Foundation
import SwiftData

// Mock implementation of UserProfileRepositoryProtocol for testing
class MockUserProfileRepository: UserProfileRepositoryProtocol {
    // MARK: - Control Properties
    
    var shouldFail = false
    var mockError: Error = ProfileError.fetchFailed
    var profileToReturn: UserProfileModel?
    var syncCalled = false
    var createCalled = false
    var updateCalled = false
    var deleteCalled = false
    
    // MARK: - BaseRepository Requirements
    
    func create(_ model: UserProfileModel) async throws {
        createCalled = true
        if shouldFail { throw mockError }
        profileToReturn = model
    }
    
    func update(_ model: UserProfileModel) async throws {
        updateCalled = true
        if shouldFail { throw mockError }
        profileToReturn = model
    }
    
    func delete(_ model: UserProfileModel) async throws {
        deleteCalled = true
        if shouldFail { throw mockError }
        profileToReturn = nil
    }
    
    func fetchById(_ id: UUID) async throws -> UserProfileModel? {
        if shouldFail { throw mockError }
        return profileToReturn?.id == id ? profileToReturn : nil
    }
    
    func fetchAll() async throws -> [UserProfileModel] {
        if shouldFail { throw mockError }
        return profileToReturn != nil ? [profileToReturn!] : []
    }
    
    func sync() async throws {
        syncCalled = true
        if shouldFail { throw mockError }
    }
    
    // MARK: - UserProfileRepositoryProtocol Requirements
    
    func fetchByUserId(_ userId: String) async throws -> UserProfileModel? {
        if shouldFail { throw mockError }
        return profileToReturn?.userId == userId ? profileToReturn : nil
    }
    
    func updateHealthGoals(_ profile: UserProfileModel, goals: [String]) async throws {
        if shouldFail { throw mockError }
        profileToReturn?.healthGoals = goals
    }
}

enum ProfileError: Error {
    case fetchFailed
    case syncFailed
    case updateFailed
}