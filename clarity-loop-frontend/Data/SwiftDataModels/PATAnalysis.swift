import Foundation
import SwiftData

@Model
final class PATAnalysis {
    // MARK: - Properties
    
    @Attribute(.unique) var analysisID: UUID
    var remoteID: String?
    
    // Analysis metadata
    var startDate: Date
    var endDate: Date
    var analysisDate: Date
    var analysisType: PATAnalysisType
    
    // Sleep stages data
    var sleepStages: [PATSleepStage]
    var totalSleepMinutes: Int
    var sleepEfficiency: Double
    var sleepLatency: Int // Minutes to fall asleep
    var wakeAfterSleepOnset: Int // WASO in minutes
    
    // Sleep quality metrics
    var remSleepMinutes: Int
    var deepSleepMinutes: Int
    var lightSleepMinutes: Int
    var awakeMinutes: Int
    
    // Analysis scores
    var overallScore: Double
    var confidenceScore: Double
    var qualityMetrics: SleepQualityMetrics
    
    // Actigraphy data
    var actigraphyData: [ActigraphyDataPoint]?
    var movementIntensity: [Double]?
    
    // Sync tracking
    var syncStatus: SyncStatus
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
    case overnight = "overnight"
    case nap = "nap"
    case extended = "extended" // Multi-day analysis
}

struct PATSleepStage: Codable {
    let timestamp: Date
    let stage: SleepStageType
    let duration: Int // Minutes
    let confidence: Double
    
    enum SleepStageType: String, Codable {
        case awake = "awake"
        case light = "light"
        case deep = "deep"
        case rem = "rem"
        
        var color: String {
            switch self {
            case .awake: return "#FF6B6B"
            case .light: return "#4ECDC4"
            case .deep: return "#45B7D1"
            case .rem: return "#96CEB4"
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