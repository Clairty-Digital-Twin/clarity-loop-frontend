import Foundation
import SwiftData

@Model
final class HealthMetric {
    // MARK: - Properties
    
    @Attribute(.unique) var localID: UUID
    var remoteID: String?
    
    var timestamp: Date
    var value: Double
    var type: HealthMetricType
    var unit: String
    
    // Sync tracking
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var syncError: String?
    
    // Metadata
    var source: String // e.g., "HealthKit", "Manual", "Device"
    var metadata: [String: String]?
    
    // Relationships
    var userProfile: UserProfileModel?
    
    // MARK: - Initialization
    
    init(
        localID: UUID = UUID(),
        remoteID: String? = nil,
        timestamp: Date,
        value: Double,
        type: HealthMetricType,
        unit: String,
        syncStatus: SyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        syncError: String? = nil,
        source: String = "HealthKit",
        metadata: [String: String]? = nil,
        userProfile: UserProfileModel? = nil
    ) {
        self.localID = localID
        self.remoteID = remoteID
        self.timestamp = timestamp
        self.value = value
        self.type = type
        self.unit = unit
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.syncError = syncError
        self.source = source
        self.metadata = metadata
        self.userProfile = userProfile
    }
}

// MARK: - Supporting Types

enum HealthMetricType: String, Codable, CaseIterable {
    case heartRate = "heart_rate"
    case bloodPressureSystolic = "blood_pressure_systolic"
    case bloodPressureDiastolic = "blood_pressure_diastolic"
    case steps = "steps"
    case sleepDuration = "sleep_duration"
    case sleepREM = "sleep_rem"
    case sleepDeep = "sleep_deep"
    case sleepLight = "sleep_light"
    case sleepAwake = "sleep_awake"
    case activeEnergy = "active_energy"
    case restingEnergy = "resting_energy"
    case exerciseMinutes = "exercise_minutes"
    case standHours = "stand_hours"
    case heartRateVariability = "hrv"
    case respiratoryRate = "respiratory_rate"
    case bodyTemperature = "body_temperature"
    case oxygenSaturation = "oxygen_saturation"
    case weight = "weight"
    case height = "height"
    case bodyMassIndex = "bmi"
    
    var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .bloodPressureSystolic: return "Systolic BP"
        case .bloodPressureDiastolic: return "Diastolic BP"
        case .steps: return "Steps"
        case .sleepDuration: return "Sleep Duration"
        case .sleepREM: return "REM Sleep"
        case .sleepDeep: return "Deep Sleep"
        case .sleepLight: return "Light Sleep"
        case .sleepAwake: return "Awake Time"
        case .activeEnergy: return "Active Calories"
        case .restingEnergy: return "Resting Calories"
        case .exerciseMinutes: return "Exercise Minutes"
        case .standHours: return "Stand Hours"
        case .heartRateVariability: return "HRV"
        case .respiratoryRate: return "Respiratory Rate"
        case .bodyTemperature: return "Body Temperature"
        case .oxygenSaturation: return "Oxygen Saturation"
        case .weight: return "Weight"
        case .height: return "Height"
        case .bodyMassIndex: return "BMI"
        }
    }
}

enum SyncStatus: String, Codable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    case conflict = "conflict"
}