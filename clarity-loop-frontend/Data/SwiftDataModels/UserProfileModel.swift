import Foundation
import SwiftData

@Model
final class UserProfileModel {
    // MARK: - Properties
    
    @Attribute(.unique) var userID: String
    var email: String
    var displayName: String
    
    // Preferences
    var preferences: UserPreferences
    var notificationSettings: NotificationSettings
    var privacySettings: PrivacySettings
    
    // Sync tracking
    var lastSync: Date?
    var syncStatus: SyncStatus
    
    // Health profile
    var dateOfBirth: Date?
    var biologicalSex: String?
    var heightInCentimeters: Double?
    var weightInKilograms: Double?
    var bloodType: String?
    
    // App settings
    var appTheme: AppTheme
    var measurementSystem: MeasurementSystem
    var language: String
    
    // Relationships
    @Relationship(deleteRule: .cascade) var healthMetrics: [HealthMetric]?
    @Relationship(deleteRule: .cascade) var patAnalyses: [PATAnalysis]?
    @Relationship(deleteRule: .cascade) var aiInsights: [AIInsight]?
    
    // MARK: - Initialization
    
    init(
        userID: String,
        email: String,
        displayName: String
    ) {
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.preferences = UserPreferences()
        self.notificationSettings = NotificationSettings()
        self.privacySettings = PrivacySettings()
        self.syncStatus = .pending
        self.appTheme = .system
        self.measurementSystem = .metric
        self.language = "en"
    }
}

// MARK: - Supporting Types

struct UserPreferences: Codable {
    var dashboardMetrics: [HealthMetricType] = [
        .heartRate,
        .steps,
        .sleepDuration,
        .activeEnergy
    ]
    var insightCategories: [InsightCategory] = InsightCategory.allCases
    var syncFrequency: SyncFrequency = .automatic
    var dataRetentionDays: Int = 365
    
    enum SyncFrequency: String, Codable {
        case automatic = "automatic"
        case hourly = "hourly"
        case daily = "daily"
        case manual = "manual"
    }
}

struct NotificationSettings: Codable {
    var healthAlerts: Bool = true
    var insightNotifications: Bool = true
    var patAnalysisComplete: Bool = true
    var syncReminders: Bool = false
    var quietHoursEnabled: Bool = true
    var quietHoursStart: Date = Date()
    var quietHoursEnd: Date = Date()
}

struct PrivacySettings: Codable {
    var shareHealthData: Bool = true
    var allowAnalytics: Bool = false
    var biometricAuthEnabled: Bool = true
    var dataEncryptionEnabled: Bool = true
}

enum AppTheme: String, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

enum MeasurementSystem: String, Codable {
    case metric = "metric"
    case imperial = "imperial"
}