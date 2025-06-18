import Foundation
import SwiftData

@Model
final class AIInsight {
    // MARK: - Properties

    // FIXED: Removed @Attribute(.unique) for CloudKit compatibility
    var insightID: UUID = UUID()
    var remoteID: String?

    // Content - FIXED: Made optional or added defaults for CloudKit
    var content: String = ""
    var summary: String?
    var title: String?

    // Metadata - FIXED: Added defaults for CloudKit
    var timestamp: Date = Date()
    var category: InsightCategory = InsightCategory.general
    var priority: InsightPriority = InsightPriority.medium
    var type: AIInsightType = AIInsightType.suggestion

    // Context
    var contextData: [String: String]?
    var relatedMetrics: [HealthMetricType]?
    var dateRange: InsightDateRange?

    // AI metadata
    var modelVersion: String?
    var confidenceScore: Double?
    var generationTime: Double? // Seconds

    // User interaction - FIXED: Added defaults for CloudKit
    var isRead: Bool = false
    var isFavorite: Bool = false
    var userRating: Int? // 1-5 stars
    var userFeedback: String?

    // Chat context
    var conversationID: UUID?
    var messageRole: MessageRole = MessageRole.assistant
    var parentMessageID: UUID?

    // Sync tracking - FIXED: Added defaults for CloudKit
    var syncStatus: SyncStatus = SyncStatus.pending
    var lastSyncedAt: Date?

    // Relationships - FIXED: Removed inverse to avoid circular reference
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
    case general
    case sleep
    case activity
    case heartHealth = "heart_health"
    case nutrition
    case mentalHealth = "mental_health"
    case medication
    case vitals

    var displayName: String {
        switch self {
        case .general: "General"
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .heartHealth: "Heart Health"
        case .nutrition: "Nutrition"
        case .mentalHealth: "Mental Health"
        case .medication: "Medication"
        case .vitals: "Vitals"
        }
    }

    var icon: String {
        switch self {
        case .general: "sparkles"
        case .sleep: "moon.fill"
        case .activity: "figure.walk"
        case .heartHealth: "heart.fill"
        case .nutrition: "fork.knife"
        case .mentalHealth: "brain.head.profile"
        case .medication: "pills.fill"
        case .vitals: "waveform.path.ecg"
        }
    }
}

enum InsightPriority: String, Codable {
    case high
    case medium
    case low

    var sortOrder: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

enum AIInsightType: String, Codable {
    case alert
    case suggestion
    case observation
    case achievement
    case trend
    case chat

    var icon: String {
        switch self {
        case .alert: "exclamationmark.triangle.fill"
        case .suggestion: "lightbulb.fill"
        case .observation: "eye.fill"
        case .achievement: "star.fill"
        case .trend: "chart.line.uptrend.xyaxis"
        case .chat: "message.fill"
        }
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
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
