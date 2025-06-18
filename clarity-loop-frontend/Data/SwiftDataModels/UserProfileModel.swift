import Foundation
import SwiftData

@Model
final class UserProfileModel {
    // MARK: - Properties

    // FIXED: Removed @Attribute(.unique) for CloudKit compatibility
    var userID: String = ""
    var email: String = ""
    var displayName: String = ""

    // Preferences - FIXED: Added defaults for CloudKit
    var preferences: UserPreferences = UserPreferences()
    var notificationSettings: NotificationSettings = NotificationSettings()
    var privacySettings: PrivacySettings = PrivacySettings()

    // Sync tracking
    var lastSync: Date?
    var syncStatus: SyncStatus = SyncStatus.pending

    // Health profile
    var dateOfBirth: Date?
    var biologicalSex: String?
    var heightInCentimeters: Double?
    var weightInKilograms: Double?
    var bloodType: String?

    // App settings - FIXED: Added defaults for CloudKit
    var appTheme: AppTheme = AppTheme.system
    var measurementSystem: MeasurementSystem = MeasurementSystem.metric
    var language: String = "en"

    // Relationships - FIXED: Added inverse relationships for CloudKit
    @Relationship(deleteRule: .cascade) var healthMetrics: [HealthMetric]?
    @Relationship(deleteRule: .cascade) var patAnalyses: [PATAnalysis]?
    @Relationship(deleteRule: .cascade, inverse: \AIInsight.userProfile) var aiInsights: [AIInsight]?

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
        .activeEnergy,
    ]
    var insightCategories: [InsightCategory] = InsightCategory.allCases
    var syncFrequency: SyncFrequency = .automatic
    var dataRetentionDays = 365

    enum SyncFrequency: String, Codable {
        case automatic
        case hourly
        case daily
        case manual
    }
}

struct NotificationSettings: Codable {
    var healthAlerts = true
    var insightNotifications = true
    var patAnalysisComplete = true
    var syncReminders = false
    var quietHoursEnabled = true
    var quietHoursStart = Date()
    var quietHoursEnd = Date()
}

struct PrivacySettings: Codable {
    var shareHealthData = true
    var allowAnalytics = false
    var biometricAuthEnabled = true
    var dataEncryptionEnabled = true
}

enum AppTheme: String, Codable {
    case light
    case dark
    case system
}

enum MeasurementSystem: String, Codable {
    case metric
    case imperial
}
