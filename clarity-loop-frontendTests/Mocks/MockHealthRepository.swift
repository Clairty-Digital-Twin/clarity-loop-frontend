import Foundation
@testable import clarity_loop_frontend

// Mock HealthMetric for testing
struct MockHealthMetric {
    let id: UUID
    let timestamp: Date
    let value: Double
    let type: HealthMetricType
    let unit: String
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var syncError: String?
    let source: String?
    let metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Double,
        type: HealthMetricType,
        unit: String,
        syncStatus: SyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        syncError: String? = nil,
        source: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.type = type
        self.unit = unit
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.syncError = syncError
        self.source = source
        self.metadata = metadata
    }
}

@MainActor
final class MockHealthRepository: HealthRepositoryProtocol {
    // MARK: - Properties
    
    private var metrics: [MockHealthMetric] = []
    private let maxBatchSize = 100
    var isLoading = false
    var pendingSyncCount = 0
    var syncError: Error?
    
    // MARK: - HealthRepositoryProtocol Implementation
    
    func create(_ model: HealthMetric) async throws {
        // Convert to mock and store
        let mock = MockHealthMetric(
            id: model.localID,
            timestamp: model.timestamp,
            value: model.value,
            type: model.type,
            unit: model.unit,
            syncStatus: model.syncStatus,
            lastSyncedAt: model.lastSyncedAt,
            syncError: model.syncError,
            source: model.source,
            metadata: model.metadata
        )
        metrics.append(mock)
    }
    
    func update(_ model: HealthMetric) async throws {
        guard let index = metrics.firstIndex(where: { $0.id == model.localID }) else {
            throw RepositoryError.modelNotFound
        }
        
        metrics[index] = MockHealthMetric(
            id: model.localID,
            timestamp: model.timestamp,
            value: model.value,
            type: model.type,
            unit: model.unit,
            syncStatus: model.syncStatus,
            lastSyncedAt: model.lastSyncedAt,
            syncError: model.syncError,
            source: model.source,
            metadata: model.metadata
        )
    }
    
    func delete(_ model: HealthMetric) async throws {
        metrics.removeAll { $0.id == model.localID }
    }
    
    func fetchAll() async throws -> [HealthMetric] {
        // Convert mocks back to HealthMetric
        metrics.map { mock in
            HealthMetric(
                localID: mock.id,
                remoteID: nil,
                timestamp: mock.timestamp,
                value: mock.value,
                type: mock.type,
                unit: mock.unit,
                syncStatus: mock.syncStatus,
                lastSyncedAt: mock.lastSyncedAt,
                syncError: mock.syncError,
                source: mock.source,
                metadata: mock.metadata,
                userProfile: nil
            )
        }
    }
    
    func sync() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate sync
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Mark all pending as synced
        for i in metrics.indices {
            if metrics[i].syncStatus == .pending {
                metrics[i].syncStatus = .synced
                metrics[i].lastSyncedAt = Date()
            }
        }
        
        pendingSyncCount = 0
    }
    
    func syncBatch(_ models: [HealthMetric]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate batch sync
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let modelIds = Set(models.map { $0.localID })
        
        for i in metrics.indices {
            if modelIds.contains(metrics[i].id) {
                metrics[i].syncStatus = .synced
                metrics[i].lastSyncedAt = Date()
            }
        }
    }
    
    func resolveSyncConflicts(for models: [HealthMetric]) async throws {
        // For testing, just mark as pending
        let modelIds = Set(models.map { $0.localID })
        
        for i in metrics.indices {
            if modelIds.contains(metrics[i].id) {
                metrics[i].syncStatus = .pending
                metrics[i].syncError = nil
            }
        }
    }
    
    // MARK: - HealthRepositoryProtocol Specific Methods
    
    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric] {
        let filtered = metrics.filter { $0.type == type && $0.timestamp >= date }
        let sorted = filtered.sorted { $0.timestamp > $1.timestamp }
        
        return sorted.map { mock in
            HealthMetric(
                localID: mock.id,
                remoteID: nil,
                timestamp: mock.timestamp,
                value: mock.value,
                type: mock.type,
                unit: mock.unit,
                syncStatus: mock.syncStatus,
                lastSyncedAt: mock.lastSyncedAt,
                syncError: mock.syncError,
                source: mock.source,
                metadata: mock.metadata,
                userProfile: nil
            )
        }
    }
    
    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric? {
        let filtered = metrics.filter { $0.type == type }
        let sorted = filtered.sorted { $0.timestamp > $1.timestamp }
        
        guard let first = sorted.first else { return nil }
        
        return HealthMetric(
            localID: first.id,
            remoteID: nil,
            timestamp: first.timestamp,
            value: first.value,
            type: first.type,
            unit: first.unit,
            syncStatus: first.syncStatus,
            lastSyncedAt: first.lastSyncedAt,
            syncError: first.syncError,
            source: first.source,
            metadata: first.metadata,
            userProfile: nil
        )
    }
    
    func fetchMetricsByDateRange(
        type: HealthMetricType,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        let filtered = metrics.filter {
            $0.type == type &&
            $0.timestamp >= startDate &&
            $0.timestamp <= endDate
        }
        let sorted = filtered.sorted { $0.timestamp < $1.timestamp }
        
        return sorted.map { mock in
            HealthMetric(
                localID: mock.id,
                remoteID: nil,
                timestamp: mock.timestamp,
                value: mock.value,
                type: mock.type,
                unit: mock.unit,
                syncStatus: mock.syncStatus,
                lastSyncedAt: mock.lastSyncedAt,
                syncError: mock.syncError,
                source: mock.source,
                metadata: mock.metadata,
                userProfile: nil
            )
        }
    }
    
    func fetchPendingSyncMetrics(limit: Int) async throws -> [HealthMetric] {
        let pending = metrics.filter { 
            $0.syncStatus == .pending || $0.syncStatus == .failed 
        }
        let limited = Array(pending.prefix(limit))
        
        return limited.map { mock in
            HealthMetric(
                localID: mock.id,
                remoteID: nil,
                timestamp: mock.timestamp,
                value: mock.value,
                type: mock.type,
                unit: mock.unit,
                syncStatus: mock.syncStatus,
                lastSyncedAt: mock.lastSyncedAt,
                syncError: mock.syncError,
                source: mock.source,
                metadata: mock.metadata,
                userProfile: nil
            )
        }
    }
    
    func fetchMetricsNeedingSync() async throws -> [HealthMetric] {
        try await fetchPendingSyncMetrics(limit: 100)
    }
    
    func batchUpload(metrics: [HealthMetric]) async throws {
        guard metrics.count <= maxBatchSize else {
            throw RepositoryError.batchOperationFailed(
                NSError(
                    domain: "MockHealthRepository",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Batch size exceeds maximum of \(maxBatchSize)"]
                )
            )
        }
        
        // Add all metrics to our mock storage
        for metric in metrics {
            try await create(metric)
        }
        
        // Update pending count
        pendingSyncCount = self.metrics.filter { 
            $0.syncStatus == .pending || $0.syncStatus == .failed 
        }.count
    }
    
    func calculateAverageMetric(
        type: HealthMetricType,
        since date: Date
    ) async throws -> Double? {
        let filtered = metrics.filter { $0.type == type && $0.timestamp >= date }
        guard !filtered.isEmpty else { return nil }
        
        let sum = filtered.reduce(0) { $0 + $1.value }
        return sum / Double(filtered.count)
    }
    
    func calculateMetricTrend(
        type: HealthMetricType,
        days: Int
    ) async throws -> HealthMetricTrend {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let filtered = metrics.filter { $0.type == type && $0.timestamp >= startDate }
        
        guard filtered.count >= 2 else {
            return HealthMetricTrend(trend: .stable, percentageChange: 0)
        }
        
        let sorted = filtered.sorted { $0.timestamp < $1.timestamp }
        let firstValue = sorted.first!.value
        let lastValue = sorted.last!.value
        
        let percentageChange = ((lastValue - firstValue) / firstValue) * 100
        
        let trend: HealthMetricTrend.Direction
        if abs(percentageChange) < 5 {
            trend = .stable
        } else if percentageChange > 0 {
            trend = .increasing
        } else {
            trend = .decreasing
        }
        
        return HealthMetricTrend(trend: trend, percentageChange: percentageChange)
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        metrics.removeAll()
        isLoading = false
        pendingSyncCount = 0
        syncError = nil
    }
    
    func createBatch(_ models: [HealthMetric]) async throws {
        for model in models {
            try await create(model)
        }
    }
}