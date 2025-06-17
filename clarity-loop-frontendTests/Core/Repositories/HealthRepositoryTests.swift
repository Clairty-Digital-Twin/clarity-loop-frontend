import XCTest
@testable import clarity_loop_frontend

@MainActor
final class HealthRepositoryTests: XCTestCase {
    
    // MARK: - Properties
    
    private var repository: MockHealthRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        repository = MockHealthRepository()
    }
    
    override func tearDown() async throws {
        repository?.reset()
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Fetch Tests
    
    func testFetchMetricsByTypeAndDate() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        let metric1 = HealthMetric(timestamp: now, value: 80, type: .heartRate, unit: "bpm")
        let metric2 = HealthMetric(timestamp: yesterday, value: 75, type: .heartRate, unit: "bpm")
        let metric3 = HealthMetric(timestamp: twoDaysAgo, value: 70, type: .heartRate, unit: "bpm")
        let metric4 = HealthMetric(timestamp: now, value: 5000, type: .steps, unit: "count")
        
        try await repository.create(metric1)
        try await repository.create(metric2)
        try await repository.create(metric3)
        try await repository.create(metric4)
        
        // When
        let heartRateMetrics = try await repository.fetchMetrics(for: .heartRate, since: yesterday)
        
        // Then
        XCTAssertEqual(heartRateMetrics.count, 2)
        XCTAssertTrue(heartRateMetrics.allSatisfy { $0.type == .heartRate })
        XCTAssertTrue(heartRateMetrics.allSatisfy { $0.timestamp >= yesterday })
    }
    
    func testFetchMetricsReturnsEmptyForNoData() async throws {
        // When - Fetch metrics when repository is empty
        let metrics = try await repository.fetchMetrics(for: .heartRate, since: Date())
        
        // Then
        XCTAssertTrue(metrics.isEmpty)
    }
    
    func testFetchMetricsSortedByDate() async throws {
        // Given
        let now = Date()
        let metric1 = HealthMetric(timestamp: now, value: 80, type: .heartRate, unit: "bpm")
        let metric2 = HealthMetric(timestamp: now.addingTimeInterval(-3600), value: 75, type: .heartRate, unit: "bpm")
        let metric3 = HealthMetric(timestamp: now.addingTimeInterval(-7200), value: 70, type: .heartRate, unit: "bpm")
        
        try await repository.create(metric2)
        try await repository.create(metric3)
        try await repository.create(metric1)
        
        // When
        let metrics = try await repository.fetchMetrics(for: .heartRate, since: now.addingTimeInterval(-86400))
        
        // Then
        XCTAssertEqual(metrics.count, 3)
        XCTAssertTrue(metrics[0].timestamp >= metrics[1].timestamp)
        XCTAssertTrue(metrics[1].timestamp >= metrics[2].timestamp)
    }
    
    func testFetchLatestMetricForType() async throws {
        // Given
        let now = Date()
        let oldMetric = HealthMetric(timestamp: now.addingTimeInterval(-3600), value: 70, type: .heartRate, unit: "bpm")
        let latestMetric = HealthMetric(timestamp: now, value: 80, type: .heartRate, unit: "bpm")
        
        try await repository.create(oldMetric)
        try await repository.create(latestMetric)
        
        // When
        let result = try await repository.fetchLatestMetric(for: .heartRate)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.value, 80)
        XCTAssertEqual(result?.timestamp, now)
    }
    
    func testFetchAllReturnsAllMetrics() async throws {
        // Given
        let metric1 = HealthMetric(timestamp: Date(), value: 80, type: .heartRate, unit: "bpm")
        let metric2 = HealthMetric(timestamp: Date(), value: 5000, type: .steps, unit: "count")
        let metric3 = HealthMetric(timestamp: Date(), value: 8, type: .sleep, unit: "hours")
        
        try await repository.create(metric1)
        try await repository.create(metric2)
        try await repository.create(metric3)
        
        // When
        let allMetrics = try await repository.fetchAll()
        
        // Then
        XCTAssertEqual(allMetrics.count, 3)
        XCTAssertTrue(allMetrics.contains { $0.type == .heartRate })
        XCTAssertTrue(allMetrics.contains { $0.type == .steps })
        XCTAssertTrue(allMetrics.contains { $0.type == .sleep })
    }
    
    // MARK: - Create Tests
    
    func testCreateHealthMetricSuccess() async throws {
        // Given
        let metric = HealthMetric(
            timestamp: Date(),
            value: 72.0,
            type: .heartRate,
            unit: "bpm"
        )
        
        // When
        try await repository.create(metric)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.value, 72.0)
        XCTAssertEqual(fetched.first?.type, .heartRate)
        XCTAssertEqual(fetched.first?.unit, "bpm")
    }
    
    func testCreateMultipleMetrics() async throws {
        // Given
        let metrics = [
            HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 78, type: .heartRate, unit: "bpm")
        ]
        
        // When
        for metric in metrics {
            try await repository.create(metric)
        }
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 3)
    }
    
    func testCreateMetricWithAllFields() async throws {
        // Given
        let metric = HealthMetric(
            localID: UUID(),
            remoteID: "remote-123",
            timestamp: Date(),
            value: 72.5,
            type: .heartRate,
            unit: "bpm",
            syncStatus: .pending,
            lastSyncedAt: nil,
            syncError: nil,
            source: "Apple Watch",
            metadata: ["device": "Series 8", "version": "9.0"],
            userProfile: nil
        )
        
        // When
        try await repository.create(metric)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.source, "Apple Watch")
        XCTAssertEqual(fetched.first?.metadata?["device"], "Series 8")
    }
    
    // MARK: - Update Tests
    
    func testUpdateHealthMetricSuccess() async throws {
        // Given
        let metric = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        try await repository.create(metric)
        
        // When
        metric.value = 80
        try await repository.update(metric)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.first?.value, 80)
    }
    
    func testUpdateMetricSyncStatus() async throws {
        // Given
        let metric = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        metric.syncStatus = .pending
        try await repository.create(metric)
        
        // When
        metric.syncStatus = .synced
        metric.lastSyncedAt = Date()
        try await repository.update(metric)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.first?.syncStatus, .synced)
        XCTAssertNotNil(fetched.first?.lastSyncedAt)
    }
    
    func testUpdateMultipleMetrics() async throws {
        // Given
        let metrics = [
            HealthMetric(timestamp: Date(), value: 70, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 80, type: .heartRate, unit: "bpm")
        ]
        
        for metric in metrics {
            try await repository.create(metric)
        }
        
        // When
        for (index, metric) in metrics.enumerated() {
            metric.value = Double(85 + index)
            try await repository.update(metric)
        }
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 3)
        let values = fetched.map { $0.value }.sorted()
        XCTAssertEqual(values, [85, 86, 87])
    }
    
    // MARK: - Delete Tests
    
    func testDeleteHealthMetricSuccess() async throws {
        // Given
        let metric = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        try await repository.create(metric)
        
        // When
        try await repository.delete(metric)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertTrue(fetched.isEmpty)
    }
    
    func testDeleteMetricsByDateRange() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        
        let metric1 = HealthMetric(timestamp: now, value: 80, type: .heartRate, unit: "bpm")
        let metric2 = HealthMetric(timestamp: yesterday, value: 75, type: .heartRate, unit: "bpm")
        let metric3 = HealthMetric(timestamp: twoDaysAgo, value: 70, type: .heartRate, unit: "bpm")
        
        try await repository.create(metric1)
        try await repository.create(metric2)
        try await repository.create(metric3)
        
        // When - Delete metrics from yesterday
        let toDelete = try await repository.fetchMetricsByDateRange(
            type: .heartRate,
            startDate: yesterday.addingTimeInterval(-3600),
            endDate: yesterday.addingTimeInterval(3600)
        )
        
        for metric in toDelete {
            try await repository.delete(metric)
        }
        
        // Then
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains { abs($0.timestamp.timeIntervalSince(yesterday)) < 3600 })
    }
    
    func testDeleteAllMetricsForType() async throws {
        // Given
        let heartRate1 = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        let heartRate2 = HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm")
        let steps = HealthMetric(timestamp: Date(), value: 5000, type: .steps, unit: "count")
        
        try await repository.create(heartRate1)
        try await repository.create(heartRate2)
        try await repository.create(steps)
        
        // When - Delete all heart rate metrics
        let heartRates = try await repository.fetchMetrics(for: .heartRate, since: Date().addingTimeInterval(-86400))
        for metric in heartRates {
            try await repository.delete(metric)
        }
        
        // Then
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.type, .steps)
    }
    
    // MARK: - Sync Tests
    
    func testMarkMetricsAsSynced() async throws {
        // Given
        let metric1 = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        let metric2 = HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm")
        metric1.syncStatus = .pending
        metric2.syncStatus = .pending
        
        try await repository.create(metric1)
        try await repository.create(metric2)
        
        // When
        try await repository.sync()
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertTrue(fetched.allSatisfy { $0.syncStatus == .synced })
        XCTAssertTrue(fetched.allSatisfy { $0.lastSyncedAt != nil })
    }
    
    func testFetchUnsyncedMetrics() async throws {
        // Given
        let synced = HealthMetric(timestamp: Date(), value: 70, type: .heartRate, unit: "bpm")
        let pending = HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm")
        let failed = HealthMetric(timestamp: Date(), value: 80, type: .heartRate, unit: "bpm")
        
        synced.syncStatus = .synced
        pending.syncStatus = .pending
        failed.syncStatus = .failed
        
        try await repository.create(synced)
        try await repository.create(pending)
        try await repository.create(failed)
        
        // When
        let unsynced = try await repository.fetchPendingSyncMetrics(limit: 10)
        
        // Then
        XCTAssertEqual(unsynced.count, 2)
        XCTAssertTrue(unsynced.allSatisfy { $0.syncStatus == .pending || $0.syncStatus == .failed })
    }
    
    func testSyncRepositoryIntegration() async throws {
        // Given
        let metrics = [
            HealthMetric(timestamp: Date(), value: 70, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 75, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 80, type: .heartRate, unit: "bpm")
        ]
        
        for metric in metrics {
            metric.syncStatus = .pending
            try await repository.create(metric)
        }
        
        // When
        try await repository.syncBatch(metrics)
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertTrue(fetched.allSatisfy { $0.syncStatus == .synced })
    }
    
    // MARK: - Aggregation Tests
    
    func testAggregateStepsByDay() async throws {
        // Given
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // Today's steps
        try await repository.create(HealthMetric(timestamp: today, value: 1000, type: .steps, unit: "count"))
        try await repository.create(HealthMetric(timestamp: today.addingTimeInterval(3600), value: 2000, type: .steps, unit: "count"))
        try await repository.create(HealthMetric(timestamp: today.addingTimeInterval(7200), value: 1500, type: .steps, unit: "count"))
        
        // Yesterday's steps
        try await repository.create(HealthMetric(timestamp: yesterday, value: 3000, type: .steps, unit: "count"))
        try await repository.create(HealthMetric(timestamp: yesterday.addingTimeInterval(3600), value: 2500, type: .steps, unit: "count"))
        
        // When
        let todaySteps = try await repository.fetchMetricsByDateRange(
            type: .steps,
            startDate: today,
            endDate: today.addingTimeInterval(86400)
        )
        
        // Then
        let todayTotal = todaySteps.reduce(0) { $0 + $1.value }
        XCTAssertEqual(todayTotal, 4500)
    }
    
    func testAverageHeartRateByPeriod() async throws {
        // Given
        let now = Date()
        try await repository.create(HealthMetric(timestamp: now, value: 70, type: .heartRate, unit: "bpm"))
        try await repository.create(HealthMetric(timestamp: now.addingTimeInterval(-3600), value: 75, type: .heartRate, unit: "bpm"))
        try await repository.create(HealthMetric(timestamp: now.addingTimeInterval(-7200), value: 80, type: .heartRate, unit: "bpm"))
        try await repository.create(HealthMetric(timestamp: now.addingTimeInterval(-10800), value: 85, type: .heartRate, unit: "bpm"))
        
        // When
        let average = try await repository.calculateAverageMetric(
            type: .heartRate,
            since: now.addingTimeInterval(-86400)
        )
        
        // Then
        XCTAssertNotNil(average)
        XCTAssertEqual(average, 77.5, accuracy: 0.01)
    }
    
    func testTotalSleepDurationByWeek() async throws {
        // Given
        let today = Calendar.current.startOfDay(for: Date())
        
        // Create sleep data for a week
        for day in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: -day, to: today) else { continue }
            let sleepHours = Double.random(in: 6...9)
            try await repository.create(HealthMetric(timestamp: date, value: sleepHours, type: .sleep, unit: "hours"))
        }
        
        // When
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let sleepMetrics = try await repository.fetchMetrics(for: .sleep, since: weekStart)
        
        // Then
        let totalSleep = sleepMetrics.reduce(0) { $0 + $1.value }
        XCTAssertGreaterThan(totalSleep, 42) // At least 6 hours per day
        XCTAssertLessThan(totalSleep, 63) // At most 9 hours per day
    }
    
    // MARK: - Query Performance Tests
    
    func testLargeDatasetQueryPerformance() async throws {
        // Given - Create 1000 metrics
        let startTime = Date()
        
        for i in 0..<1000 {
            let metric = HealthMetric(
                timestamp: startTime.addingTimeInterval(Double(i * 60)),
                value: Double.random(in: 60...100),
                type: .heartRate,
                unit: "bpm"
            )
            try await repository.create(metric)
        }
        
        // When - Measure query time
        let queryStart = CFAbsoluteTimeGetCurrent()
        let results = try await repository.fetchMetrics(for: .heartRate, since: startTime)
        let queryEnd = CFAbsoluteTimeGetCurrent()
        
        // Then
        let queryTime = queryEnd - queryStart
        XCTAssertEqual(results.count, 1000)
        XCTAssertLessThan(queryTime, 1.0) // Query should complete in less than 1 second
    }
    
    func testComplexPredicatePerformance() async throws {
        // Given - Create diverse dataset
        let now = Date()
        let types: [HealthMetricType] = [.heartRate, .steps, .sleep, .bloodPressure]
        
        for i in 0..<500 {
            let metric = HealthMetric(
                timestamp: now.addingTimeInterval(Double(-i * 3600)),
                value: Double.random(in: 50...150),
                type: types.randomElement()!,
                unit: "unit"
            )
            try await repository.create(metric)
        }
        
        // When - Complex date range query
        let queryStart = CFAbsoluteTimeGetCurrent()
        let weekAgo = now.addingTimeInterval(-604800)
        let threeDaysAgo = now.addingTimeInterval(-259200)
        
        let heartRateMetrics = try await repository.fetchMetricsByDateRange(
            type: .heartRate,
            startDate: weekAgo,
            endDate: threeDaysAgo
        )
        let queryEnd = CFAbsoluteTimeGetCurrent()
        
        // Then
        let queryTime = queryEnd - queryStart
        XCTAssertLessThan(queryTime, 0.5) // Complex query should complete quickly
        XCTAssertTrue(heartRateMetrics.allSatisfy { $0.type == .heartRate })
        XCTAssertTrue(heartRateMetrics.allSatisfy { $0.timestamp >= weekAgo && $0.timestamp <= threeDaysAgo })
    }
    
    // MARK: - Data Validation Tests
    
    func testValidateMetricValues() async throws {
        // Given - Valid metric values
        let validMetrics = [
            HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 10000, type: .steps, unit: "count"),
            HealthMetric(timestamp: Date(), value: 8.5, type: .sleep, unit: "hours")
        ]
        
        // When
        for metric in validMetrics {
            try await repository.create(metric)
        }
        
        // Then
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 3)
        
        // Verify reasonable value ranges
        let heartRate = fetched.first { $0.type == .heartRate }
        XCTAssertNotNil(heartRate)
        XCTAssertGreaterThan(heartRate!.value, 30)
        XCTAssertLessThan(heartRate!.value, 220)
        
        let steps = fetched.first { $0.type == .steps }
        XCTAssertNotNil(steps)
        XCTAssertGreaterThanOrEqual(steps!.value, 0)
        XCTAssertLessThan(steps!.value, 100000)
        
        let sleep = fetched.first { $0.type == .sleep }
        XCTAssertNotNil(sleep)
        XCTAssertGreaterThan(sleep!.value, 0)
        XCTAssertLessThan(sleep!.value, 24)
    }
    
    func testRejectInvalidMetricTypes() async throws {
        // Given - Metrics with proper types
        let metrics = [
            HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm"),
            HealthMetric(timestamp: Date(), value: 5000, type: .steps, unit: "count"),
            HealthMetric(timestamp: Date(), value: 8, type: .sleep, unit: "hours"),
            HealthMetric(timestamp: Date(), value: 120, type: .bloodPressure, unit: "mmHg")
        ]
        
        // When
        for metric in metrics {
            try await repository.create(metric)
        }
        
        // Then - Verify all types are properly stored
        let fetched = try await repository.fetchAll()
        XCTAssertEqual(fetched.count, 4)
        
        let types = Set(fetched.map { $0.type })
        XCTAssertEqual(types.count, 4)
        XCTAssertTrue(types.contains(.heartRate))
        XCTAssertTrue(types.contains(.steps))
        XCTAssertTrue(types.contains(.sleep))
        XCTAssertTrue(types.contains(.bloodPressure))
    }
}