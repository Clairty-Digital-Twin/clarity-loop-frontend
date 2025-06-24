import Foundation
@testable import clarity_loop_frontend

// MARK: - Additional Properties for MockAPIClient

extension MockAPIClient {
    // Singleton to store handlers
    private static var handlers = Handlers()
    
    private struct Handlers {
        var getHealthDataHandler: ((Int, Int) async throws -> PaginatedMetricsResponseDTO)?
        var syncHealthKitDataHandler: ((HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO)?
        var getHealthKitSyncStatusHandler: ((String) async throws -> HealthKitSyncStatusDTO)?
        var getHealthKitUploadStatusHandler: ((String) async throws -> HealthKitUploadStatusDTO)?
        var getProcessingStatusHandler: ((UUID) async throws -> HealthDataProcessingStatusDTO)?
        var analyzeStepDataHandler: ((StepDataRequestDTO) async throws -> StepAnalysisResponseDTO)?
        var analyzeActigraphyHandler: ((DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO)?
        var getPATAnalysisHandler: ((String) async throws -> PATAnalysisResponseDTO)?
    }
    
    // Handler properties
    var getHealthDataHandler: ((Int, Int) async throws -> PaginatedMetricsResponseDTO)? {
        get { MockAPIClient.handlers.getHealthDataHandler }
        set { MockAPIClient.handlers.getHealthDataHandler = newValue }
    }
    
    var syncHealthKitDataHandler: ((HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO)? {
        get { MockAPIClient.handlers.syncHealthKitDataHandler }
        set { MockAPIClient.handlers.syncHealthKitDataHandler = newValue }
    }
    
    var getHealthKitSyncStatusHandler: ((String) async throws -> HealthKitSyncStatusDTO)? {
        get { MockAPIClient.handlers.getHealthKitSyncStatusHandler }
        set { MockAPIClient.handlers.getHealthKitSyncStatusHandler = newValue }
    }
    
    var getHealthKitUploadStatusHandler: ((String) async throws -> HealthKitUploadStatusDTO)? {
        get { MockAPIClient.handlers.getHealthKitUploadStatusHandler }
        set { MockAPIClient.handlers.getHealthKitUploadStatusHandler = newValue }
    }
    
    var getProcessingStatusHandler: ((UUID) async throws -> HealthDataProcessingStatusDTO)? {
        get { MockAPIClient.handlers.getProcessingStatusHandler }
        set { MockAPIClient.handlers.getProcessingStatusHandler = newValue }
    }
    
    var analyzeStepDataHandler: ((StepDataRequestDTO) async throws -> StepAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.analyzeStepDataHandler }
        set { MockAPIClient.handlers.analyzeStepDataHandler = newValue }
    }
    
    var analyzeActigraphyHandler: ((DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.analyzeActigraphyHandler }
        set { MockAPIClient.handlers.analyzeActigraphyHandler = newValue }
    }
    
    var getPATAnalysisHandler: ((String) async throws -> PATAnalysisResponseDTO)? {
        get { MockAPIClient.handlers.getPATAnalysisHandler }
        set { MockAPIClient.handlers.getPATAnalysisHandler = newValue }
    }
    
    // Reset all handlers
    static func resetHandlers() {
        handlers = Handlers()
    }
}

// MARK: - Health Data Methods Implementation

extension MockAPIClient {
    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthDataHandler {
            return try await handler(page, limit)
        }
        
        // Default empty response
        return PaginatedMetricsResponseDTO(
            metrics: [],
            pagination: PaginationInfoDTO(
                page: page,
                limit: limit,
                totalPages: 0,
                totalCount: 0,
                hasNextPage: false,
                hasPreviousPage: false
            ),
            metadata: nil
        )
    }
    
    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = syncHealthKitDataHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return HealthKitSyncResponseDTO(
            syncId: UUID().uuidString,
            status: "initiated",
            startDate: requestDTO.startDate,
            endDate: requestDTO.endDate,
            metricsToSync: requestDTO.metricTypes?.count ?? 0,
            syncedMetrics: 0,
            errors: nil,
            estimatedTimeRemaining: 60,
            timestamp: Date()
        )
    }
    
    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthKitSyncStatusHandler {
            return try await handler(syncId)
        }
        
        // Default response
        return HealthKitSyncStatusDTO(
            syncId: syncId,
            status: "in_progress",
            progress: 0.5,
            syncedMetrics: 50,
            totalMetrics: 100,
            errors: nil,
            completedAt: nil,
            timestamp: Date()
        )
    }
    
    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthKitUploadStatusHandler {
            return try await handler(uploadId)
        }
        
        // Default response
        return HealthKitUploadStatusDTO(
            uploadId: uploadId,
            status: "processing",
            processedSamples: 0,
            totalSamples: 0,
            errors: nil,
            timestamp: Date()
        )
    }
    
    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getProcessingStatusHandler {
            return try await handler(id)
        }
        
        // Default response
        return HealthDataProcessingStatusDTO(
            id: id,
            status: "processing",
            stage: "validation",
            progress: 0.25,
            startedAt: Date(),
            completedAt: nil,
            results: nil,
            errors: nil,
            timestamp: Date()
        )
    }
}

// MARK: - PAT Analysis Methods Implementation

extension MockAPIClient {
    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = analyzeStepDataHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return StepAnalysisResponseDTO(
            analysisId: UUID().uuidString,
            status: "completed",
            message: "Analysis completed",
            data: nil,
            createdAt: Date()
        )
    }
    
    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = analyzeActigraphyHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return ActigraphyAnalysisResponseDTO(
            analysisId: UUID().uuidString,
            status: "completed",
            message: "Analysis completed",
            data: nil,
            createdAt: Date()
        )
    }
    
    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getPATAnalysisHandler {
            return try await handler(id)
        }
        
        // Default response
        return PATAnalysisResponseDTO(
            id: id,
            userId: "test-user",
            status: "completed",
            patFeatures: nil,
            analysis: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date()
        )
    }
}