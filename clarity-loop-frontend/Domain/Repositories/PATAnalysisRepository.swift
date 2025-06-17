import Foundation
import SwiftData
import Observation

// MARK: - PAT Analysis Repository Implementation

@Observable
final class PATAnalysisRepository: ObservableBaseRepository<PATAnalysis>, PATAnalysisRepositoryProtocol {
    
    // MARK: - Query Operations
    
    func fetchAnalyses(between startDate: Date, and endDate: Date) async throws -> [PATAnalysis] {
        let predicate = #Predicate<PATAnalysis> { analysis in
            analysis.startDate >= startDate && analysis.endDate <= endDate
        }
        
        var descriptor = FetchDescriptor<PATAnalysis>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
        
        return try await fetch(descriptor: descriptor)
    }
    
    func fetchLatestAnalysis() async throws -> PATAnalysis? {
        var descriptor = FetchDescriptor<PATAnalysis>()
        descriptor.sortBy = [SortDescriptor(\.analysisDate, order: .reverse)]
        descriptor.fetchLimit = 1
        
        let results = try await fetch(descriptor: descriptor)
        return results.first
    }
    
    // MARK: - Sync Operations
    
    override func sync() async throws {
        await setLoading(true)
        defer { Task { @MainActor in setLoading(false) } }
        
        do {
            // Get pending analyses
            let pendingAnalyses = try await fetchPendingSyncAnalyses()
            guard !pendingAnalyses.isEmpty else {
                await updateSyncStatus(pendingCount: 0)
                return
            }
            
            await updateSyncStatus(pendingCount: pendingAnalyses.count)
            
            // TODO: Implement actual API sync
            // For now, simulate sync
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Mark as synced
            for analysis in pendingAnalyses {
                analysis.syncStatus = .synced
                analysis.lastSyncedAt = Date()
            }
            
            try modelContext.save()
            await updateSyncStatus(pendingCount: 0)
            
        } catch {
            await setSyncError(error)
            throw RepositoryError.syncFailed(error)
        }
    }
    
    override func syncBatch(_ models: [PATAnalysis]) async throws {
        // PAT analyses are typically large, so sync one at a time
        for model in models {
            await setLoading(true)
            defer { Task { @MainActor in setLoading(false) } }
            
            // TODO: Implement actual API sync
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            model.syncStatus = .synced
            model.lastSyncedAt = Date()
        }
        
        try modelContext.save()
    }
    
    override func resolveSyncConflicts(for models: [PATAnalysis]) async throws {
        // For PAT analyses, newer analysis wins
        for model in models {
            // In a real implementation, compare timestamps with server
            model.syncStatus = .pending
        }
        try modelContext.save()
    }
    
    // MARK: - Private Helpers
    
    private func fetchPendingSyncAnalyses() async throws -> [PATAnalysis] {
        let pendingStatus = SyncStatus.pending.rawValue
        let failedStatus = SyncStatus.failed.rawValue
        
        let predicate = #Predicate<PATAnalysis> { analysis in
            analysis.syncStatus.rawValue == pendingStatus || analysis.syncStatus.rawValue == failedStatus
        }
        
        var descriptor = FetchDescriptor<PATAnalysis>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.analysisDate)]
        
        return try await fetch(descriptor: descriptor)
    }
}