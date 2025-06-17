import Foundation
import SwiftData

@Model
final class AIInsight {
    // MARK: - Properties
    
    @Attribute(.unique) var insightID: UUID
    var remoteID: String?
    
    // Content
    var content: String
    var summary: String?
    var title: String?
    
    // Metadata
    var timestamp: Date
    var category: InsightCategory
    var priority: InsightPriority
    var type: AIInsightType
    
    // Context
    var contextData: [String: String]?
    var relatedMetrics: [HealthMetricType]?
    var dateRange: InsightDateRange?
    
    // AI metadata
    var modelVersion: String?
    var confidenceScore: Double?
    var generationTime: Double? // Seconds
    
    // User interaction
    var isRead: Bool
    var isFavorite: Bool
    var userRating: Int? // 1-5 stars
    var userFeedback: String?
    
    // Chat context
    var conversationID: UUID?
    var messageRole: MessageRole
    var parentMessageID: UUID?
    
    // Sync tracking
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    
    // Relationships
    var userProfile: UserProfileModel?
    var patAnalysis: PATAnalysis?
    
    // MARK: - Initialization
    
    init(
        content: String,
        category: InsightCategory,
        type: AIInsightType = .suggestion,
        messageRole: MessageRole = .assistant
    ) {
        self.insightID = UUID()
        self.content = content
        self.timestamp = Date()
        self.category = category
        self.priority = .medium
        self.type = type
        self.messageRole = messageRole
        self.isRead = false
        self.isFavorite = false
        self.syncStatus = .pending
    }
}

// MARK: - Supporting Types

enum InsightCategory: String, Codable, CaseIterable {
    case general = "general"
    case sleep = "sleep"
    case activity = "activity"
    case heartHealth = "heart_health"
    case nutrition = "nutrition"
    case mentalHealth = "mental_health"
    case medication = "medication"
    case vitals = "vitals"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .heartHealth: return "Heart Health"
        case .nutrition: return "Nutrition"
        case .mentalHealth: return "Mental Health"
        case .medication: return "Medication"
        case .vitals: return "Vitals"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .sleep: return "moon.fill"
        case .activity: return "figure.walk"
        case .heartHealth: return "heart.fill"
        case .nutrition: return "fork.knife"
        case .mentalHealth: return "brain.head.profile"
        case .medication: return "pills.fill"
        case .vitals: return "waveform.path.ecg"
        }
    }
}

enum InsightPriority: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

enum AIInsightType: String, Codable {
    case alert = "alert"
    case suggestion = "suggestion"
    case observation = "observation"
    case achievement = "achievement"
    case trend = "trend"
    case chat = "chat"
    
    var icon: String {
        switch self {
        case .alert: return "exclamationmark.triangle.fill"
        case .suggestion: return "lightbulb.fill"
        case .observation: return "eye.fill"
        case .achievement: return "star.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .chat: return "message.fill"
        }
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

struct InsightDateRange: Codable {
    let startDate: Date
    let endDate: Date
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Conversation Management

extension AIInsight {
    static func createUserMessage(content: String, category: InsightCategory = .general) -> AIInsight {
        let message = AIInsight(
            content: content,
            category: category,
            type: .chat,
            messageRole: .user
        )
        message.conversationID = UUID()
        return message
    }
    
    static func createAssistantMessage(
        content: String,
        category: InsightCategory,
        conversationID: UUID,
        parentMessageID: UUID? = nil
    ) -> AIInsight {
        let message = AIInsight(
            content: content,
            category: category,
            type: .chat,
            messageRole: .assistant
        )
        message.conversationID = conversationID
        message.parentMessageID = parentMessageID
        return message
    }
}

// MARK: - Search Support

extension AIInsight {
    var searchableText: String {
        [title, content, summary].compactMap { $0 }.joined(separator: " ")
    }
}