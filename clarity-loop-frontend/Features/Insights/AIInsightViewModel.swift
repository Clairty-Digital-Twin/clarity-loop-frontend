import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AIInsightViewModel: BaseViewModel {
    // MARK: - Properties
    
    private(set) var insightsState: ViewState<[AIInsight]> = .idle
    private(set) var generationState: ViewState<AIInsight> = .idle
    private(set) var selectedTimeframe: InsightTimeframe = .week
    private(set) var selectedCategory: InsightCategory?
    
    // MARK: - Dependencies
    
    private let insightRepository: AIInsightRepository
    private let insightsRepo: InsightsRepositoryProtocol
    private let healthRepository: HealthRepository
    private let authService: AuthServiceProtocol
    
    // MARK: - Computed Properties
    
    var insights: [AIInsight] {
        insightsState.value ?? []
    }
    
    var filteredInsights: [AIInsight] {
        var filtered = insights
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by timeframe
        let cutoffDate = selectedTimeframe.cutoffDate
        filtered = filtered.filter { $0.generatedAt >= cutoffDate }
        
        return filtered
    }
    
    var hasUnreadInsights: Bool {
        insights.contains { !$0.isRead }
    }
    
    var insightStats: InsightStats {
        let total = insights.count
        let unread = insights.filter { !$0.isRead }.count
        let highPriority = insights.filter { $0.priority == .high }.count
        let averageConfidence = insights.isEmpty ? 0 : insights.compactMap { $0.confidenceScore }.reduce(0, +) / Double(insights.count)
        
        return InsightStats(
            totalInsights: total,
            unreadInsights: unread,
            highPriorityInsights: highPriority,
            averageConfidence: averageConfidence
        )
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        insightRepository: AIInsightRepository,
        insightsRepo: InsightsRepositoryProtocol,
        healthRepository: HealthRepository,
        authService: AuthServiceProtocol
    ) {
        self.insightRepository = insightRepository
        self.insightsRepo = insightsRepo
        self.healthRepository = healthRepository
        self.authService = authService
        super.init(modelContext: modelContext)
    }
    
    // MARK: - Public Methods
    
    func loadInsights() async {
        insightsState = .loading
        
        do {
            // Load local insights
            let localInsights = try await insightRepository.fetchAll()
            
            if !localInsights.isEmpty {
                insightsState = .loaded(localInsights)
            }
            
            // Sync with backend
            await syncInsights()
            
            // Reload after sync
            let updatedInsights = try await insightRepository.fetchAll()
            insightsState = updatedInsights.isEmpty ? .empty : .loaded(updatedInsights)
        } catch {
            insightsState = .error(error)
            handle(error: error)
        }
    }
    
    func generateNewInsight() async {
        generationState = .loading
        
        do {
            // Check if we have recent health data
            let hasData = await checkRecentHealthData()
            guard hasData else {
                throw InsightError.insufficientData
            }
            
            // Get user ID
            guard let userId = await authService.currentUser?.id else {
                throw InsightError.notAuthenticated
            }
            
            // Request insight generation
            let response = try await insightsRepo.generateInsight(userId: userId)
            
            // Create local AIInsight model
            let insight = AIInsight(
                insightId: response.data.id,
                narrative: response.data.narrative,
                category: categorizeInsight(response.data.narrative),
                priority: determinePriority(response.data),
                generatedAt: response.data.generatedAt,
                confidenceScore: response.data.confidenceScore,
                keyInsights: response.data.keyInsights,
                recommendations: response.data.recommendations,
                dataPointsAnalyzed: response.data.dataPoints.count
            )
            
            // Save locally
            try await insightRepository.create(insight)
            
            generationState = .loaded(insight)
            
            // Reload insights list
            await loadInsights()
        } catch {
            generationState = .error(error)
            handle(error: error)
        }
    }
    
    func markAsRead(_ insight: AIInsight) async {
        insight.isRead = true
        insight.lastModified = Date()
        
        do {
            try await insightRepository.update(insight)
        } catch {
            handle(error: error)
        }
    }
    
    func toggleBookmark(_ insight: AIInsight) async {
        insight.isBookmarked.toggle()
        insight.lastModified = Date()
        
        do {
            try await insightRepository.update(insight)
        } catch {
            handle(error: error)
        }
    }
    
    func deleteInsight(_ insight: AIInsight) async {
        do {
            try await insightRepository.delete(insight)
            await loadInsights()
        } catch {
            handle(error: error)
        }
    }
    
    func selectTimeframe(_ timeframe: InsightTimeframe) {
        selectedTimeframe = timeframe
    }
    
    func selectCategory(_ category: InsightCategory?) {
        selectedCategory = category
    }
    
    func exportInsights() async -> URL? {
        do {
            let insights = filteredInsights
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(insights)
            
            let fileName = "ai_insights_\(Date().ISO8601Format()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url)
            return url
        } catch {
            handle(error: error)
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func syncInsights() async {
        do {
            guard let userId = await authService.currentUser?.id else { return }
            
            // Fetch latest insights from backend
            let response = try await insightsRepo.getInsightHistory(
                userId: userId,
                limit: 50,
                offset: 0
            )
            
            // Convert and save new insights
            for insightDTO in response.data.insights {
                // Check if we already have this insight
                let existingInsight = try await insightRepository.fetchByInsightId(insightDTO.id)
                
                if existingInsight == nil {
                    // Fetch full insight details
                    let fullInsight = try await insightsRepo.getInsight(
                        userId: userId,
                        insightId: insightDTO.id
                    )
                    
                    let insight = AIInsight(
                        insightId: fullInsight.data.id,
                        narrative: fullInsight.data.narrative,
                        category: categorizeInsight(fullInsight.data.narrative),
                        priority: determinePriority(fullInsight.data),
                        generatedAt: fullInsight.data.generatedAt,
                        confidenceScore: fullInsight.data.confidenceScore,
                        keyInsights: fullInsight.data.keyInsights,
                        recommendations: fullInsight.data.recommendations,
                        dataPointsAnalyzed: fullInsight.data.dataPoints.count
                    )
                    
                    try await insightRepository.create(insight)
                }
            }
            
            // Mark repository as synced
            try await insightRepository.sync()
        } catch {
            print("Insight sync error: \(error)")
        }
    }
    
    private func checkRecentHealthData() async -> Bool {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate)!
            
            let metrics = try await healthRepository.fetchMetrics(
                from: startDate,
                to: endDate,
                type: nil
            )
            
            return !metrics.isEmpty
        } catch {
            return false
        }
    }
    
    private func categorizeInsight(_ narrative: String) -> InsightCategory {
        let lowercased = narrative.lowercased()
        
        if lowercased.contains("sleep") || lowercased.contains("rest") {
            return .sleep
        } else if lowercased.contains("heart") || lowercased.contains("cardiovascular") {
            return .cardiovascular
        } else if lowercased.contains("activity") || lowercased.contains("exercise") || lowercased.contains("step") {
            return .activity
        } else if lowercased.contains("nutrition") || lowercased.contains("diet") || lowercased.contains("calor") {
            return .nutrition
        } else if lowercased.contains("stress") || lowercased.contains("mental") || lowercased.contains("mood") {
            return .mentalHealth
        } else {
            return .general
        }
    }
    
    private func determinePriority(_ insight: InsightResponseDTO) -> InsightPriority {
        // High priority if confidence is high and has many recommendations
        if insight.confidenceScore > 0.8 && insight.recommendations.count > 2 {
            return .high
        } else if insight.confidenceScore > 0.6 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Supporting Types

enum InsightTimeframe: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case all = "All Time"
    
    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date())!
        case .all:
            return Date.distantPast
        }
    }
}

enum InsightCategory: String, CaseIterable {
    case general = "General"
    case sleep = "Sleep"
    case activity = "Activity"
    case cardiovascular = "Heart Health"
    case nutrition = "Nutrition"
    case mentalHealth = "Mental Health"
    
    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .sleep: return "moon.fill"
        case .activity: return "figure.walk"
        case .cardiovascular: return "heart.fill"
        case .nutrition: return "leaf.fill"
        case .mentalHealth: return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .purple
        case .sleep: return .indigo
        case .activity: return .orange
        case .cardiovascular: return .red
        case .nutrition: return .green
        case .mentalHealth: return .blue
        }
    }
}

enum InsightPriority: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

struct InsightStats {
    let totalInsights: Int
    let unreadInsights: Int
    let highPriorityInsights: Int
    let averageConfidence: Double
}

enum InsightError: LocalizedError {
    case insufficientData
    case notAuthenticated
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Not enough health data to generate insights. Please sync more data."
        case .notAuthenticated:
            return "You must be signed in to generate insights"
        case .generationFailed:
            return "Failed to generate insight. Please try again."
        }
    }
}