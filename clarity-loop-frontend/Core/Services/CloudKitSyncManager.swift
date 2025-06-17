import Foundation
import CloudKit
import SwiftData
import Combine

/// Manages CloudKit sync for SwiftData models
@MainActor
final class CloudKitSyncManager: ObservableObject {
    // MARK: - Properties
    
    static var shared: CloudKitSyncManager?
    
    static func configure(modelContext: ModelContext) {
        shared = CloudKitSyncManager(modelContext: modelContext)
    }
    
    @Published private(set) var syncState: CloudKitSyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncErrors: [CloudKitSyncError] = []
    @Published private(set) var pendingChanges: Int = 0
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let modelContext: ModelContext
    
    private var syncOperations: Set<CKOperation> = []
    private var subscriptions: Set<CKSubscription> = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let containerIdentifier = "iCloud.com.clarity.health"
    private let syncBatchSize = 400 // CloudKit limit
    private let maxRetries = 3
    
    // MARK: - Initialization
    
    private init(modelContext: ModelContext) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.modelContext = modelContext
        
        setupCloudKit()
        observeAccountStatus()
    }
    
    // MARK: - Public Methods
    
    /// Start automatic CloudKit sync
    func startSync() {
        guard isCloudKitAvailable else {
            syncState = .disabled(reason: "CloudKit not available")
            return
        }
        
        Task {
            try? await setupSubscriptions()
            await performInitialSync()
        }
    }
    
    /// Stop CloudKit sync
    func stopSync() {
        for operation in syncOperations {
            operation.cancel()
        }
        syncOperations.removeAll()
        syncState = .idle
    }
    
    /// Force sync all data
    func forceSync() async {
        syncState = .syncing
        
        do {
            // Upload local changes
            try await uploadPendingChanges()
            
            // Download remote changes
            try await downloadRemoteChanges()
            
            // Resolve conflicts
            try await resolveConflicts()
            
            lastSyncDate = Date()
            syncState = .synced
            
        } catch {
            syncState = .error(error)
            syncErrors.append(CloudKitSyncError(
                timestamp: Date(),
                operation: "forceSync",
                error: error,
                recordID: nil
            ))
        }
    }
    
    /// Reset sync metadata
    func resetSync() async {
        // Clear sync tokens
        UserDefaults.standard.removeObject(forKey: "cloudKitServerChangeToken")
        
        // Reset sync status on all models
        do {
            let healthMetrics = try modelContext.fetch(FetchDescriptor<HealthMetric>())
            for metric in healthMetrics {
                metric.syncStatus = .pending
            }
            
            try modelContext.save()
        } catch {
            print("Failed to reset sync: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private var isCloudKitAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func setupCloudKit() {
        // Configure CloudKit for efficient sync
        // Note: Batch size will be handled at the operation level
    }
    
    private func observeAccountStatus() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAccountChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAccountChange() async {
        let status = try? await container.accountStatus()
        
        switch status {
        case .available:
            if syncState == .disabled(reason: "CloudKit not available") {
                Task {
                    startSync()
                }
            }
        case .noAccount:
            syncState = .disabled(reason: "No iCloud account")
        case .restricted:
            syncState = .disabled(reason: "iCloud restricted")
        case .couldNotDetermine:
            syncState = .disabled(reason: "Could not determine iCloud status")
        default:
            break
        }
    }
    
    // MARK: - Sync Operations
    
    private func performInitialSync() async {
        syncState = .syncing
        
        do {
            // Create record zones if needed
            try await createRecordZones()
            
            // Upload all local data
            try await uploadAllData()
            
            // Download all remote data
            try await downloadAllData()
            
            lastSyncDate = Date()
            syncState = .synced
            
        } catch {
            syncState = .error(error)
            syncErrors.append(CloudKitSyncError(
                timestamp: Date(),
                operation: "initialSync",
                error: error,
                recordID: nil
            ))
        }
    }
    
    private func uploadPendingChanges() async throws {
        // Fetch pending changes
        let pendingHealthMetrics = try modelContext.fetch(
            FetchDescriptor<HealthMetric>(
                predicate: #Predicate { metric in
                    metric.syncStatus.rawValue == "pending"
                }
            )
        )
        
        let pendingInsights = try modelContext.fetch(
            FetchDescriptor<AIInsight>(
                predicate: #Predicate { insight in
                    insight.syncStatus.rawValue == "pending"
                }
            )
        )
        
        let pendingAnalyses = try modelContext.fetch(
            FetchDescriptor<PATAnalysis>(
                predicate: #Predicate { analysis in
                    analysis.syncStatus.rawValue == "pending"
                }
            )
        )
        
        pendingChanges = pendingHealthMetrics.count + pendingInsights.count + pendingAnalyses.count
        
        // Upload in batches
        try await uploadHealthMetrics(pendingHealthMetrics)
        try await uploadInsights(pendingInsights)
        try await uploadAnalyses(pendingAnalyses)
        
        pendingChanges = 0
    }
    
    private func uploadHealthMetrics(_ metrics: [HealthMetric]) async throws {
        let chunks = stride(from: 0, to: metrics.count, by: syncBatchSize).map {
            Array(metrics[$0..<min($0 + syncBatchSize, metrics.count)])
        }
        
        for chunk in chunks {
            let records = chunk.map { createRecord(from: $0) }
            
            let operation = CKModifyRecordsOperation(
                recordsToSave: records,
                recordIDsToDelete: nil
            )
            
            operation.perRecordSaveBlock = { [weak self] recordID, result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        if let metric = chunk.first(where: { $0.localID.uuidString == recordID.recordName }) {
                            metric.syncStatus = SyncStatus.synced
                            metric.lastSyncedAt = Date()
                        }
                    case .failure(let error):
                        self?.handleSyncError(error, for: recordID)
                    }
                }
            }
            
            try await performOperation(operation)
        }
        
        try modelContext.save()
    }
    
    private func uploadInsights(_ insights: [AIInsight]) async throws {
        // Similar to uploadHealthMetrics
    }
    
    private func uploadAnalyses(_ analyses: [PATAnalysis]) async throws {
        // Similar to uploadHealthMetrics
    }
    
    private func downloadRemoteChanges() async throws {
        let serverChangeToken = UserDefaults.standard.object(forKey: "cloudKitServerChangeToken") as? Data
        
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = serverChangeToken.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }
        
        var configurationsPerZone = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
        configurationsPerZone[recordZoneID] = configuration
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [recordZoneID], configurationsByRecordZoneID: configurationsPerZone)
        
        var downloadedRecords: [CKRecord] = []
        
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                downloadedRecords.append(record)
            case .failure(let error):
                print("Failed to fetch record \(recordID): \(error)")
            }
        }
        
        operation.recordZoneFetchResultBlock = { [weak self] zoneID, result in
            switch result {
            case .success(let fetchResult):
                let token = fetchResult.serverChangeToken
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                    UserDefaults.standard.set(data, forKey: "cloudKitServerChangeToken")
                }
            case .failure(let error):
                self?.handleSyncError(error, for: nil)
            }
        }
        
        try await performOperation(operation)
        
        // Process downloaded records
        try await processDownloadedRecords(downloadedRecords)
    }
    
    private func processDownloadedRecords(_ records: [CKRecord]) async throws {
        for record in records {
            switch record.recordType {
            case "HealthMetric":
                try await processHealthMetricRecord(record)
            case "AIInsight":
                try await processInsightRecord(record)
            case "PATAnalysis":
                try await processAnalysisRecord(record)
            default:
                break
            }
        }
        
        try modelContext.save()
    }
    
    private func processHealthMetricRecord(_ record: CKRecord) async throws {
        let localID = UUID(uuidString: record.recordID.recordName)!
        
        // Check if already exists
        let existing = try modelContext.fetch(
            FetchDescriptor<HealthMetric>(
                predicate: #Predicate { $0.localID == localID }
            )
        ).first
        
        if let existing = existing {
            // Update if remote is newer
            if let remoteModified = record.modificationDate,
               remoteModified > existing.timestamp {
                updateHealthMetric(existing, from: record)
            }
        } else {
            // Create new
            let metric = createHealthMetric(from: record)
            modelContext.insert(metric)
        }
    }
    
    private func processInsightRecord(_ record: CKRecord) async throws {
        // Similar to processHealthMetricRecord
    }
    
    private func processAnalysisRecord(_ record: CKRecord) async throws {
        // Similar to processHealthMetricRecord
    }
    
    // MARK: - Record Conversion
    
    private func createRecord(from metric: HealthMetric) -> CKRecord {
        let recordID = CKRecord.ID(recordName: metric.localID.uuidString, zoneID: recordZoneID)
        let record = CKRecord(recordType: "HealthMetric", recordID: recordID)
        
        record["type"] = metric.type.rawValue
        record["value"] = metric.value
        record["unit"] = metric.unit
        record["timestamp"] = metric.timestamp
        record["source"] = metric.source
        if let metadata = metric.metadata {
            record["metadata"] = try? JSONSerialization.data(withJSONObject: metadata) as CKRecordValue
        }
        
        return record
    }
    
    private func createHealthMetric(from record: CKRecord) -> HealthMetric {
        let metric = HealthMetric(
            timestamp: record["timestamp"] as! Date,
            value: record["value"] as! Double,
            type: HealthMetricType(rawValue: record["type"] as! String)!,
            unit: record["unit"] as! String
        )
        
        metric.localID = UUID(uuidString: record.recordID.recordName)!
        metric.source = record["source"] as? String ?? "CloudKit"
        if let metadataData = record["metadata"] as? Data,
           let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: String] {
            metric.metadata = metadata
        }
        metric.syncStatus = SyncStatus.synced
        metric.lastSyncedAt = Date()
        
        return metric
    }
    
    private func updateHealthMetric(_ metric: HealthMetric, from record: CKRecord) {
        metric.value = record["value"] as! Double
        metric.timestamp = record["timestamp"] as! Date
        metric.metadata = record["metadata"] as? [String: String]
        metric.syncStatus = SyncStatus.synced
        metric.lastSyncedAt = Date()
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts() async throws {
        // Implement conflict resolution strategy
        // For now, last write wins
    }
    
    // MARK: - CloudKit Setup
    
    private var recordZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "HealthData", ownerName: CKCurrentUserDefaultName)
    }
    
    private func createRecordZones() async throws {
        let zone = CKRecordZone(zoneID: recordZoneID)
        
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )
        
        try await performOperation(operation)
    }
    
    private func setupSubscriptions() async throws {
        // Subscribe to changes
        let subscription = CKDatabaseSubscription(subscriptionID: "health-data-changes")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        
        try await performOperation(operation)
    }
    
    // MARK: - Operation Helpers
    
    private func performOperation(_ operation: CKDatabaseOperation) async throws {
        syncOperations.insert(operation)
        defer { syncOperations.remove(operation) }
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.database = privateDatabase
            operation.qualityOfService = .userInitiated
            
            if let modifyOp = operation as? CKModifyRecordsOperation {
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } else if let fetchOp = operation as? CKFetchRecordZoneChangesOperation {
                fetchOp.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } else {
                operation.completionBlock = {
                    continuation.resume()
                }
            }
            
            container.add(operation)
        }
    }
    
    private func handleSyncError(_ error: Error, for recordID: CKRecord.ID?) {
        syncErrors.append(CloudKitSyncError(
            timestamp: Date(),
            operation: "sync",
            error: error,
            recordID: recordID
        ))
        
        // Handle specific errors
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                // Retry later
                break
            case .quotaExceeded:
                syncState = .error(error)
            default:
                break
            }
        }
    }
    
    private func downloadAllData() async throws {
        // Implement full download for initial sync
    }
    
    private func uploadAllData() async throws {
        // Implement full upload for initial sync
    }
}

// MARK: - Supporting Types

enum CloudKitSyncState: Equatable {
    case idle
    case syncing
    case synced
    case error(Error)
    case disabled(reason: String)
    
    static func == (lhs: CloudKitSyncState, rhs: CloudKitSyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.synced, .synced):
            return true
        case (.disabled(let lhsReason), .disabled(let rhsReason)):
            return lhsReason == rhsReason
        case (.error(let lhsError), .error(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}

struct CloudKitSyncError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let operation: String
    let error: Error
    let recordID: CKRecord.ID?
}