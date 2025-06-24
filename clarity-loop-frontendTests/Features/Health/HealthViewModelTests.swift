import XCTest
import SwiftData
import Combine
@testable import clarity_loop_frontend

@MainActor
final class HealthViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewModel: TestableHealthViewModel!
    private var modelContext: ModelContext!
    private var mockHealthRepository: MockHealthRepository!
    private var mockHealthKitService: MockHealthKitService!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test model context
        let container = try ModelContainer(for: HealthMetric.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        modelContext = ModelContext(container)
        
        // Setup mocks
        mockHealthKitService = MockHealthKitService()
        mockHealthRepository = MockHealthRepository(modelContext: modelContext)
        
        viewModel = TestableHealthViewModel(
            modelContext: modelContext,
            healthRepository: mockHealthRepository,
            healthKitService: mockHealthKitService
        )
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        viewModel = nil
        mockHealthRepository = nil
        mockHealthKitService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Loading Metrics Tests
    
    func testLoadMetricsSuccess() async throws {
        // Arrange
        mockHealthRepository.setupMockData(days: 3)
        
        // Act
        await viewModel.loadMetrics()
        
        // Assert
        switch viewModel.metricsState {
        case .loaded(let metrics):
            XCTAssertGreaterThan(metrics.count, 0, "Should have loaded metrics")
            XCTAssertTrue(mockHealthRepository.fetchMetricsCalled, "Should have called fetchMetrics")
            
            // Verify the loaded metrics match what we put in the mock
            let stepMetrics = metrics.filter { $0.type == .steps }
            let heartRateMetrics = metrics.filter { $0.type == .heartRate }
            let sleepMetrics = metrics.filter { $0.type == .sleepDuration }
            
            XCTAssertGreaterThan(stepMetrics.count, 0, "Should have step metrics")
            XCTAssertGreaterThan(heartRateMetrics.count, 0, "Should have heart rate metrics")
            XCTAssertGreaterThan(sleepMetrics.count, 0, "Should have sleep metrics")
        default:
            XCTFail("Expected loaded state with metrics, but got \(viewModel.metricsState)")
        }
    }
    
    func testLoadMetricsUpdatesStateToLoaded() async throws {
        // Arrange
        mockHealthRepository.addMockMetric(type: .steps, value: 5000)
        XCTAssertEqual(viewModel.metricsState, .idle, "Should start in idle state")
        
        // Act
        await viewModel.loadMetrics()
        
        // Assert
        if case .loaded(let metrics) = viewModel.metricsState {
            XCTAssertEqual(metrics.count, 1, "Should have exactly 1 metric")
            XCTAssertEqual(metrics.first?.value, 5000, "Should have correct value")
        } else {
            XCTFail("Expected loaded state, got \(viewModel.metricsState)")
        }
    }
    
    func testLoadMetricsHandlesEmptyData() async throws {
        // Arrange
        mockHealthRepository.shouldReturnEmpty = true
        
        // Act
        await viewModel.loadMetrics()
        
        // Assert
        XCTAssertEqual(viewModel.metricsState, .empty, "Should be in empty state when no metrics exist")
        XCTAssertTrue(mockHealthRepository.fetchMetricsCalled, "Should have attempted to fetch metrics")
    }
    
    func testLoadMetricsHandlesError() async throws {
        // Arrange
        mockHealthRepository.shouldFail = true
        mockHealthRepository.mockError = APIError.networkError(URLError(.badServerResponse))
        
        // Act
        await viewModel.loadMetrics()
        
        // Assert
        if case .error(let error) = viewModel.metricsState {
            XCTAssertNotNil(error, "Should have an error")
            XCTAssertTrue(mockHealthRepository.fetchMetricsCalled, "Should have attempted to fetch metrics")
        } else {
            XCTFail("Expected error state, got \(viewModel.metricsState)")
        }
    }
    
    // MARK: - Date Range Tests
    
    func testSelectDateRangeUpdatesMetrics() async throws {
        // Arrange
        mockHealthRepository.setupMockData(days: 30) // 30 days of data
        let initialDateRange = viewModel.selectedDateRange
        
        // Act - Change to day view
        viewModel.selectDateRange(.day)
        try? await Task.sleep(nanoseconds: 100_000_000) // Give async task time to complete
        
        // Assert
        XCTAssertEqual(viewModel.selectedDateRange, .day, "Date range should be updated to day")
        XCTAssertNotEqual(viewModel.selectedDateRange, initialDateRange, "Date range should have changed")
        XCTAssertTrue(mockHealthRepository.fetchMetricsCalled, "Should have fetched metrics after date range change")
    }
    
    func testDateRangeFiltersMetricsCorrectly() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    // MARK: - Metric Type Selection Tests
    
    func testSelectMetricTypeUpdatesView() async throws {
        // Arrange
        mockHealthRepository.setupMockData(days: 7)
        XCTAssertNil(viewModel.selectedMetricType, "Should start with no selected type")
        
        // Act
        viewModel.selectMetricType(.steps)
        try? await Task.sleep(nanoseconds: 100_000_000) // Give async task time
        
        // Assert
        XCTAssertEqual(viewModel.selectedMetricType, .steps, "Should have selected steps")
        XCTAssertTrue(mockHealthRepository.fetchMetricsCalled, "Should have fetched metrics")
        XCTAssertEqual(mockHealthRepository.capturedFetchType, .steps, "Should have fetched only steps")
    }
    
    func testMultipleMetricTypeSelection() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    // MARK: - HealthKit Sync Tests
    
    func testSyncWithHealthKitSuccess() async throws {
        // Arrange
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockStepCount = 12345
        mockHealthKitService.mockRestingHeartRate = 65
        mockHealthKitService.mockSleepData = SleepData(
            totalTimeInBed: 28800, // 8 hours
            totalTimeAsleep: 25200, // 7 hours  
            sleepEfficiency: 0.875
        )
        
        // Act
        print("TEST: Before sync - isHealthKitAuthorized = \(viewModel.isHealthKitAuthorized)")
        print("TEST: MockHealthKitService.shouldSucceed = \(mockHealthKitService.shouldSucceed)")
        
        // Allow some time for async operations
        await viewModel.syncHealthData()
        
        // Wait a bit for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        print("TEST: After sync - syncState = \(viewModel.syncState)")
        print("TEST: createBatchCalled = \(mockHealthRepository.createBatchCalled)")
        print("TEST: syncCalled = \(mockHealthRepository.syncCalled)")
        print("TEST: capturedCreateBatchMetrics = \(mockHealthRepository.capturedCreateBatchMetrics?.count ?? 0)")
        
        // Assert basic sync behavior first
        XCTAssertTrue(mockHealthRepository.createBatchCalled, "Should have called createBatch")
        XCTAssertTrue(mockHealthRepository.syncCalled, "Should have called sync")
        
        // Check if metrics were captured
        if let createdMetrics = mockHealthRepository.capturedCreateBatchMetrics {
            XCTAssertEqual(createdMetrics.count, 3, "Should have created 3 metrics")
            XCTAssertTrue(createdMetrics.contains { $0.type == .steps }, "Should have steps")
            XCTAssertTrue(createdMetrics.contains { $0.type == .heartRate }, "Should have heart rate")
            XCTAssertTrue(createdMetrics.contains { $0.type == .sleepDuration }, "Should have sleep")
        } else {
            XCTFail("No metrics were captured during batch creation")
        }
        
        // Finally check sync state
        switch viewModel.syncState {
        case .loaded(let status):
            XCTAssertEqual(status, .synced, "Sync status should be synced")
        case .error(let error):
            XCTFail("Sync failed with error: \(error)")
        case .loading:
            XCTFail("Sync is still loading")
        case .idle:
            XCTFail("Sync never started")
        case .empty:
            XCTFail("Sync returned empty state")
        }
    }
    
    func testSyncWithHealthKitRequiresAuthorization() async throws {
        // Arrange - HealthKit not available
        mockHealthKitService.shouldSucceed = false
        
        // Act
        await viewModel.syncHealthData()
        
        // Assert
        // When HealthKit is not authorized, it should request authorization
        // The view model's isHealthKitAuthorized should reflect the mock's state
        XCTAssertFalse(viewModel.isHealthKitAuthorized, "HealthKit should not be authorized")
    }
    
    func testSyncWithHealthKitHandlesPartialSync() async throws {
        // Arrange - Set up partial data (no sleep data)
        mockHealthKitService.shouldSucceed = true
        mockHealthKitService.mockStepCount = 8000
        mockHealthKitService.mockRestingHeartRate = 70
        mockHealthKitService.mockSleepData = nil // No sleep data
        
        // Act
        await viewModel.syncHealthData()
        
        // Assert
        if case .loaded(let status) = viewModel.syncState {
            XCTAssertEqual(status, .synced, "Sync should complete even with partial data")
            
            if let createdMetrics = mockHealthRepository.capturedCreateBatchMetrics {
                XCTAssertEqual(createdMetrics.count, 2, "Should have created 2 metrics (no sleep)")
                XCTAssertTrue(createdMetrics.contains { $0.type == .steps }, "Should have steps")
                XCTAssertTrue(createdMetrics.contains { $0.type == .heartRate }, "Should have heart rate")
                XCTAssertFalse(createdMetrics.contains { $0.type == .sleepDuration }, "Should NOT have sleep")
            }
        } else {
            XCTFail("Expected successful sync state")
        }
    }
    
    // MARK: - Summary Calculation Tests
    
    func testCalculateSummaryForSteps() async throws {
        // Arrange
        let stepValues = [5000.0, 8000.0, 10000.0, 12000.0, 6000.0]
        for (index, value) in stepValues.enumerated() {
            mockHealthRepository.addMockMetric(
                type: .steps,
                value: value,
                date: Date().addingTimeInterval(TimeInterval(-index * 86400)) // Past days
            )
        }
        
        // Act
        await viewModel.loadMetrics()
        
        // Assert
        let stepMetrics = viewModel.filteredMetrics.filter { $0.type == .steps }
        XCTAssertEqual(stepMetrics.count, stepValues.count, "Should have all step metrics")
        
        // Verify we can calculate average
        let average = stepMetrics.compactMap { $0.value }.reduce(0, +) / Double(stepMetrics.count)
        XCTAssertEqual(average, 8200, accuracy: 0.1, "Average steps should be 8200")
    }
    
    func testCalculateSummaryForHeartRate() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    func testCalculateSummaryForSleep() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    // MARK: - Mock Data Generation Tests
    
    func testGenerateMockDataCreatesValidMetrics() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    func testGenerateMockDataRespectsDateRange() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    // MARK: - Chart Data Tests
    
    func testChartDataGenerationForDayView() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    func testChartDataGenerationForWeekView() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    func testChartDataGenerationForMonthView() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    // MARK: - Performance Tests
    
    func testLoadingLargeDatasetPerformance() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
    
    func testMemoryUsageWithMultipleMetricTypes() async throws {
        // TODO: Implement test
        XCTSkip("Placeholder test - needs implementation")
    }
}

// MARK: - Mock Health Repository

