import Foundation
import SwiftData
import Observation

// MARK: - Health Repository Implementation

@Observable
final class HealthRepository: ObservableBaseRepository<HealthMetric>, HealthRepositoryProtocol {
    
    // MARK: - Properties
    
    private let maxBatchSize = 100
    private var syncTask: Task<Void, Error>?
    
    // MARK: - Query Operations
    
    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric] {
        let predicate = #Predicate<HealthMetric> { metric in
            metric.type == type && metric.timestamp >= date
        }
        
        var descriptor = FetchDescriptor<HealthMetric>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        
        return try await fetch(descriptor: descriptor)
    }
    
    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric? {
        let predicate = #Predicate<HealthMetric> { metric in
            metric.type == type
        }
        
        var descriptor = FetchDescriptor<HealthMetric>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 1
        
        let results = try await fetch(descriptor: descriptor)
        return results.first
    }
    
    func fetchMetricsByDateRange(
        type: HealthMetricType,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        let predicate = #Predicate<HealthMetric> { metric in
            metric.type == type &&
            metric.timestamp >= startDate &&
            metric.timestamp <= endDate
        }
        
        var descriptor = FetchDescriptor<HealthMetric>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        
        return try await fetch(descriptor: descriptor)
    }
    
    func fetchPendingSyncMetrics(limit: Int = 100) async throws -> [HealthMetric] {
        let pendingStatus = SyncStatus.pending.rawValue
        let failedStatus = SyncStatus.failed.rawValue
        
        let predicate = #Predicate<HealthMetric> { metric in
            metric.syncStatus.rawValue == pendingStatus || metric.syncStatus.rawValue == failedStatus
        }
        
        var descriptor = FetchDescriptor<HealthMetric>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        descriptor.fetchLimit = limit
        
        return try await fetch(descriptor: descriptor)
    }
    
    func fetchMetricsNeedingSync() async throws -> [HealthMetric] {
        // Use the same logic as fetchPendingSyncMetrics
        return try await fetchPendingSyncMetrics()
    }
    
    // MARK: - Batch Operations
    
    func batchUpload(metrics: [HealthMetric]) async throws {
        // Validate batch size
        guard metrics.count <= maxBatchSize else {
            throw RepositoryError.batchOperationFailed(
                NSError(
                    domain: "HealthRepository",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Batch size exceeds maximum of \(maxBatchSize)"]
                )
            )
        }
        
        // Process in batches if needed
        let chunks = metrics.chunked(into: maxBatchSize)
        
        for chunk in chunks {
            try await createBatch(chunk)
            
            // Mark for sync
            for metric in chunk {
                metric.syncStatus = .pending
            }
        }
        
        // Trigger sync after batch upload
        try await sync()
    }
    
    // MARK: - Sync Operations
    
    override func sync() async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }
        
        do {
            // Get pending metrics
            let pendingMetrics = try await fetchPendingSyncMetrics()
            guard !pendingMetrics.isEmpty else {
                await updateSyncStatus(pendingCount: 0)
                return
            }
            
            await updateSyncStatus(pendingCount: pendingMetrics.count)
            
            // TODO: Implement actual API sync when BackendAPIClient has health endpoints
            // For now, simulate sync with delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Mark as synced
            for metric in pendingMetrics {
                metric.syncStatus = .synced
                metric.lastSyncedAt = Date()
                metric.syncError = nil
            }
            
            try modelContext.save()
            await updateSyncStatus(pendingCount: 0)
            
        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }
    
    override func syncBatch(_ models: [HealthMetric]) async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }
        
        do {
            // Process in chunks
            let chunks = models.chunked(into: maxBatchSize)
            
            for chunk in chunks {
                // TODO: Implement actual API sync
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Mark as synced
                for metric in chunk {
                    metric.syncStatus = .synced
                    metric.lastSyncedAt = Date()
                    metric.syncError = nil
                }
            }
            
            try modelContext.save()
            
        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }
    
    override func resolveSyncConflicts(for models: [HealthMetric]) async throws {
        // Implement last-write-wins strategy
        for metric in models {
            if metric.remoteID != nil {
                // In a real implementation, we would fetch the remote version
                // and compare timestamps to resolve conflicts
                
                // For now, local wins
                metric.syncStatus = .pending
                metric.syncError = nil
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Statistics
    
    func calculateAverageMetric(
        type: HealthMetricType,
        since date: Date
    ) async throws -> Double? {
        let metrics = try await fetchMetrics(for: type, since: date)
        guard !metrics.isEmpty else { return nil }
        
        let sum = metrics.reduce(0) { $0 + $1.value }
        return sum / Double(metrics.count)
    }
    
    func calculateMetricTrend(
        type: HealthMetricType,
        days: Int
    ) async throws -> HealthMetricTrend {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let metrics = try await fetchMetrics(for: type, since: startDate)
        
        guard metrics.count >= 2 else {
            return HealthMetricTrend(trend: .stable, percentageChange: 0)
        }
        
        // Calculate trend using simple linear regression
        let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
        let firstValue = sortedMetrics.first!.value
        let lastValue = sortedMetrics.last!.value
        
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
    
    // MARK: - Cleanup
    
    deinit {
        syncTask?.cancel()
    }
}

// MARK: - Health Metric Trend

struct HealthMetricTrend {
    enum Direction {
        case increasing
        case decreasing
        case stable
    }
    
    let trend: Direction
    let percentageChange: Double
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Mock Health Data Generator (for development/testing)

#if DEBUG
extension HealthRepository {
    func generateMockData(days: Int = 7) async throws {
        let calendar = Calendar.current
        let now = Date()
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Generate heart rate data (every hour)
            for hour in 0..<24 {
                guard let timestamp = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: date)) else { continue }
                
                let heartRate = HealthMetric(
                    localID: UUID(),
                    remoteID: nil,
                    timestamp: timestamp,
                    value: Double.random(in: 60...100),
                    type: .heartRate,
                    unit: "bpm",
                    syncStatus: .pending,
                    lastSyncedAt: nil,
                    syncError: nil,
                    source: "Mock",
                    metadata: ["device": "Simulator"],
                    userProfile: nil
                )
                
                try await create(heartRate)
            }
            
            // Generate steps data (every 30 minutes during waking hours)
            for halfHour in 12..<40 { // 6 AM to 10 PM
                guard let timestamp = calendar.date(
                    byAdding: .minute,
                    value: halfHour * 30,
                    to: calendar.startOfDay(for: date)
                ) else { continue }
                
                let steps = HealthMetric(
                    localID: UUID(),
                    remoteID: nil,
                    timestamp: timestamp,
                    value: Double.random(in: 50...500),
                    type: .steps,
                    unit: "count",
                    syncStatus: .pending,
                    lastSyncedAt: nil,
                    syncError: nil,
                    source: "Mock",
                    metadata: ["device": "Simulator"],
                    userProfile: nil
                )
                
                try await create(steps)
            }
        }
    }
}
#endif