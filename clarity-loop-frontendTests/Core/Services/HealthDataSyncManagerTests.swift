import XCTest
@testable import clarity_loop_frontend

final class HealthDataSyncManagerTests: XCTestCase {
    
    private var sut: HealthDataSyncManager!
    private var mockHealthKitService: MockHealthKitService!
    private var mockAuthService: MockAuthService!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        mockHealthKitService = MockHealthKitService()
        mockAuthService = MockAuthService()
        sut = HealthDataSyncManager(
            healthKitService: mockHealthKitService,
            authService: mockAuthService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockHealthKitService = nil
        mockAuthService = nil
        super.tearDown()
    }
    
    @MainActor
    func testIncrementalSync() async throws {
        // Given
        let userId = "test-user-123"
        mockAuthService.currentUser = AuthUser(
            id: userId,
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        let mockSamples = [
            HealthKitSampleDTO(
                sampleType: "stepCount",
                value: 1000,
                categoryValue: nil,
                unit: "count",
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(-3000),
                metadata: nil,
                sourceRevision: nil
            )
        ]
        
        mockHealthKitService.mockHealthDataUpload = HealthKitUploadRequestDTO(
            userId: userId,
            samples: mockSamples,
            deviceInfo: DeviceInfoDTO(
                manufacturer: "Apple",
                model: "iPhone",
                osVersion: "17.0",
                appVersion: "1.0"
            ),
            timestamp: Date()
        )
        
        mockHealthKitService.mockUploadResponse = HealthDataUploadResponseDTO(
            success: true,
            processedSamples: mockSamples.count,
            errors: [],
            message: "Success"
        )
        
        // When - First sync
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertEqual(sut.syncProgress, 1.0)
        
        let firstSyncDate = sut.lastSyncDate!
        
        // When - Second sync (incremental)
        // Reset mock data to simulate new data
        let newMockSamples = [
            HealthKitSampleDTO(
                sampleType: "heartRate",
                value: 72,
                categoryValue: nil,
                unit: "bpm",
                startDate: Date().addingTimeInterval(-1800),
                endDate: Date().addingTimeInterval(-1700),
                metadata: nil,
                sourceRevision: nil
            )
        ]
        
        mockHealthKitService.mockHealthDataUpload = HealthKitUploadRequestDTO(
            userId: userId,
            samples: newMockSamples,
            deviceInfo: DeviceInfoDTO(
                manufacturer: "Apple",
                model: "iPhone",
                osVersion: "17.0",
                appVersion: "1.0"
            ),
            timestamp: Date()
        )
        
        await sut.syncHealthData()
        
        // Then - Verify incremental sync
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertGreaterThan(sut.lastSyncDate!, firstSyncDate)
        
        // Verify the date range used for fetching
        if let lastFetchCall = mockHealthKitService.fetchHealthDataCalls.last {
            XCTAssertEqual(lastFetchCall.startDate.timeIntervalSince1970, 
                          firstSyncDate.timeIntervalSince1970, 
                          accuracy: 1.0)
        }
    }
    
    @MainActor
    func testSyncWithNoNewData() async throws {
        // Given
        mockAuthService.currentUser = AuthUser(
            id: "test-user",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Mock empty response
        mockHealthKitService.mockHealthDataUpload = HealthKitUploadRequestDTO(
            userId: "test-user",
            samples: [],
            deviceInfo: DeviceInfoDTO(
                manufacturer: "Apple",
                model: "iPhone",
                osVersion: "17.0",
                appVersion: "1.0"
            ),
            timestamp: Date()
        )
        
        // When
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertNotNil(sut.lastSyncDate)
        XCTAssertEqual(sut.syncProgress, 1.0)
    }
    
    @MainActor
    func testSyncFailure() async throws {
        // Given
        mockAuthService.currentUser = AuthUser(
            id: "test-user",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        mockHealthKitService.mockHealthDataUpload = HealthKitUploadRequestDTO(
            userId: "test-user",
            samples: [
                HealthKitSampleDTO(
                    sampleType: "stepCount",
                    value: 100,
                    categoryValue: nil,
                    unit: "count",
                    startDate: Date(),
                    endDate: Date(),
                    metadata: nil,
                    sourceRevision: nil
                )
            ],
            deviceInfo: DeviceInfoDTO(
                manufacturer: "Apple",
                model: "iPhone",
                osVersion: "17.0",
                appVersion: "1.0"
            ),
            timestamp: Date()
        )
        
        mockHealthKitService.mockUploadResponse = HealthDataUploadResponseDTO(
            success: false,
            processedSamples: 0,
            errors: ["Upload failed"],
            message: "Server error"
        )
        
        // When
        await sut.syncHealthData()
        
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNotNil(sut.syncError)
        XCTAssertNil(sut.lastSyncDate)
    }
}

// MARK: - Mock Extensions

extension MockHealthKitService {
    struct FetchHealthDataCall {
        let startDate: Date
        let endDate: Date
        let userId: String
    }
    
    var fetchHealthDataCalls: [FetchHealthDataCall] {
        return calls.compactMap { call in
            if case let .fetchHealthDataForUpload(from: start, to: end, userId: userId) = call {
                return FetchHealthDataCall(startDate: start, endDate: end, userId: userId)
            }
            return nil
        }
    }
}