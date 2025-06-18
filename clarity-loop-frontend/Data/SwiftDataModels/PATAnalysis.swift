import Foundation
import SwiftData

@Model
final class PATAnalysis {
    // MARK: - Properties

    // FIXED: Removed @Attribute(.unique) for CloudKit compatibility
    var analysisID: UUID = UUID()
    var remoteID: String?

    // Analysis metadata - FIXED: Added defaults for CloudKit
    var startDate: Date = Date()
    var endDate: Date = Date()
    var analysisDate: Date = Date()
    var analysisType: PATAnalysisType = .overnight

    // Sleep stages data - FIXED: Added defaults for CloudKit
    var sleepStages: [PATSleepStage] = []
    var totalSleepMinutes: Int = 0
    var sleepEfficiency: Double = 0.0
    var sleepLatency: Int = 0 // Minutes to fall asleep
    var wakeAfterSleepOnset: Int = 0 // WASO in minutes

    // Sleep quality metrics - FIXED: Added defaults for CloudKit
    var remSleepMinutes: Int = 0
    var deepSleepMinutes: Int = 0
    var lightSleepMinutes: Int = 0
    var awakeMinutes: Int = 0

    // Analysis scores - FIXED: Added defaults for CloudKit
    var overallScore: Double = 0.0
    var confidenceScore: Double = 0.0
    var qualityMetrics: SleepQualityMetrics = SleepQualityMetrics()

    // Actigraphy data
    var actigraphyData: [ActigraphyDataPoint]?
    var movementIntensity: [Double]?

    // Sync tracking - FIXED: Added defaults for CloudKit
    var syncStatus: SyncStatus = .pending
    var lastSyncedAt: Date?

    // Relationships
    var userProfile: UserProfileModel?
    @Relationship(deleteRule: .cascade) var relatedInsights: [AIInsight]?

    // MARK: - Initialization

    init(
        startDate: Date,
        endDate: Date,
        analysisType: PATAnalysisType = .overnight
    ) {
        self.analysisID = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.analysisDate = Date()
        self.analysisType = analysisType
        self.sleepStages = []
        self.totalSleepMinutes = 0
        self.sleepEfficiency = 0
        self.sleepLatency = 0
        self.wakeAfterSleepOnset = 0
        self.remSleepMinutes = 0
        self.deepSleepMinutes = 0
        self.lightSleepMinutes = 0
        self.awakeMinutes = 0
        self.overallScore = 0
        self.confidenceScore = 0
        self.qualityMetrics = SleepQualityMetrics()
        self.syncStatus = .pending
    }
}

// MARK: - Supporting Types

enum PATAnalysisType: String, Codable {
    case overnight
    case nap
    case extended // Multi-day analysis
}

struct PATSleepStage: Codable {
    let timestamp: Date
    let stage: SleepStageType
    let duration: Int // Minutes
    let confidence: Double

    enum SleepStageType: String, Codable {
        case awake
        case light
        case deep
        case rem

        var color: String {
            switch self {
            case .awake: "#FF6B6B"
            case .light: "#4ECDC4"
            case .deep: "#45B7D1"
            case .rem: "#96CEB4"
            }
        }
    }
}

struct ActigraphyDataPoint: Codable {
    let timestamp: Date
    let movementCount: Int
    let intensity: Double
    let ambientLight: Double?
    let soundLevel: Double?
}

struct SleepQualityMetrics: Codable {
    var continuityScore: Double = 0 // How uninterrupted the sleep was
    var depthScore: Double = 0 // Quality of deep sleep
    var regularityScore: Double = 0 // Consistency of sleep patterns
    var restorationScore: Double = 0 // How restorative the sleep was

    var averageScore: Double {
        (continuityScore + depthScore + regularityScore + restorationScore) / 4
    }
}

// MARK: - Hypnogram Generation

extension PATAnalysis {
    var hypnogramData: [(Date, PATSleepStage.SleepStageType)] {
        sleepStages.map { ($0.timestamp, $0.stage) }
    }

    var sleepSummary: String {
        """
        Total Sleep: \(totalSleepMinutes / 60)h \(totalSleepMinutes % 60)m
        Efficiency: \(Int(sleepEfficiency * 100))%
        REM: \(remSleepMinutes)m | Deep: \(deepSleepMinutes)m | Light: \(lightSleepMinutes)m
        """
    }
}
