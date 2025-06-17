@testable import clarity_loop_frontend
import Foundation
import SwiftData

// Mock implementation of HealthRepositoryProtocol for testing
class MockHealthRepository: HealthRepositoryProtocol {
    // MARK: - Control Properties
    
    var shouldFail = false
    var mockError: Error = HealthError.fetchFailed
    var metricsToReturn: [HealthMetric] = []
    var syncCalled = false
    var batchUploadCalled = false
    var uploadedMetrics: [HealthMetric] = []
    
    // MARK: - BaseRepository Requirements
    
    func create(_ model: HealthMetric) async throws {
        if shouldFail { throw mockError }
        metricsToReturn.append(model)
    }
    
    func update(_ model: HealthMetric) async throws {
        if shouldFail { throw mockError }
        if let index = metricsToReturn.firstIndex(where: { $0.id == model.id }) {
            metricsToReturn[index] = model
        }
    }
    
    func delete(_ model: HealthMetric) async throws {
        if shouldFail { throw mockError }
        metricsToReturn.removeAll { $0.id == model.id }
    }
    
    func fetchById(_ id: UUID) async throws -> HealthMetric? {
        if shouldFail { throw mockError }
        return metricsToReturn.first { $0.id == id }
    }
    
    func fetchAll() async throws -> [HealthMetric] {
        if shouldFail { throw mockError }
        return metricsToReturn
    }
    
    func sync() async throws {
        syncCalled = true
        if shouldFail { throw mockError }
    }
    
    // MARK: - HealthRepositoryProtocol Requirements
    
    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric] {
        if shouldFail { throw mockError }
        return metricsToReturn.filter { $0.type == type && $0.timestamp >= date }
    }
    
    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric? {
        if shouldFail { throw mockError }
        return metricsToReturn
            .filter { $0.type == type }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }
    
    func batchUpload(metrics: [HealthMetric]) async throws {
        batchUploadCalled = true
        if shouldFail { throw mockError }
        uploadedMetrics.append(contentsOf: metrics)
        metricsToReturn.append(contentsOf: metrics)
    }
}

enum HealthError: Error {
    case fetchFailed
    case syncFailed
    case uploadFailed
}