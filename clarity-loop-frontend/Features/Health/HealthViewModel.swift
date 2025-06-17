import Foundation
import Observation
import SwiftData
import HealthKit

@Observable
@MainActor
final class HealthViewModel: BaseViewModel {
    // MARK: - Properties
    
    private(set) var metricsState: ViewState<[HealthMetric]> = .idle
    private(set) var syncState: ViewState<SyncStatus> = .idle
    private(set) var selectedDateRange: DateRange = .week
    private(set) var selectedMetricType: HealthMetricType?
    
    // MARK: - Dependencies
    
    private let healthRepository: HealthRepository
    private let healthKitService: HealthKitServiceProtocol
    
    // MARK: - Computed Properties
    
    var metrics: [HealthMetric] {
        metricsState.value ?? []
    }
    
    var isHealthKitAuthorized: Bool {
        healthKitService.isAuthorized
    }
    
    var filteredMetrics: [HealthMetric] {
        guard let type = selectedMetricType else { return metrics }
        return metrics.filter { $0.type == type }
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        healthRepository: HealthRepository,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.healthRepository = healthRepository
        self.healthKitService = healthKitService
        super.init(modelContext: modelContext)
    }
    
    // MARK: - Public Methods
    
    func loadMetrics() async {
        metricsState = .loading
        
        do {
            let endDate = Date()
            let startDate = selectedDateRange.startDate(from: endDate)
            
            let metrics = try await healthRepository.fetchMetrics(
                from: startDate,
                to: endDate,
                type: selectedMetricType
            )
            
            metricsState = metrics.isEmpty ? .empty : .loaded(metrics)
        } catch {
            metricsState = .error(error)
            handle(error: error)
        }
    }
    
    func selectDateRange(_ range: DateRange) {
        selectedDateRange = range
        Task {
            await loadMetrics()
        }
    }
    
    func selectMetricType(_ type: HealthMetricType?) {
        selectedMetricType = type
        Task {
            await loadMetrics()
        }
    }
    
    func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
            await syncHealthData()
        } catch {
            handle(error: error)
        }
    }
    
    func syncHealthData() async {
        guard isHealthKitAuthorized else {
            await requestHealthKitAuthorization()
            return
        }
        
        syncState = .loading
        
        do {
            // Fetch latest data from HealthKit
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            
            let dailyMetrics = try await healthKitService.fetchAllDailyMetrics(
                from: startDate,
                to: endDate
            )
            
            // Convert to HealthMetric models and save
            var healthMetrics: [HealthMetric] = []
            
            for (date, metrics) in dailyMetrics {
                // Steps
                if metrics.stepCount > 0 {
                    let stepMetric = HealthMetric(
                        type: .steps,
                        value: Double(metrics.stepCount),
                        unit: "steps",
                        date: date,
                        source: .healthKit
                    )
                    healthMetrics.append(stepMetric)
                }
                
                // Heart Rate
                if let heartRate = metrics.restingHeartRate {
                    let heartMetric = HealthMetric(
                        type: .heartRate,
                        value: heartRate,
                        unit: "bpm",
                        date: date,
                        source: .healthKit
                    )
                    healthMetrics.append(heartMetric)
                }
                
                // Sleep
                if let sleepData = metrics.sleepData {
                    let sleepMetric = HealthMetric(
                        type: .sleep,
                        value: sleepData.totalTimeAsleep / 3600, // Convert to hours
                        unit: "hours",
                        date: date,
                        source: .healthKit,
                        metadata: [
                            "efficiency": "\(sleepData.sleepEfficiency)",
                            "timeInBed": "\(sleepData.totalTimeInBed)"
                        ]
                    )
                    healthMetrics.append(sleepMetric)
                }
            }
            
            // Save to repository
            try await healthRepository.createBatch(healthMetrics)
            
            // Sync with backend
            try await healthRepository.sync()
            
            syncState = .loaded(.synced)
            
            // Reload metrics to show new data
            await loadMetrics()
        } catch {
            syncState = .error(error)
            handle(error: error)
        }
    }
    
    func deleteMetric(_ metric: HealthMetric) async {
        do {
            try await healthRepository.delete(metric)
            await loadMetrics()
        } catch {
            handle(error: error)
        }
    }
    
    func exportMetrics() async -> URL? {
        do {
            let metrics = self.metrics
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(metrics)
            
            let fileName = "health_metrics_\(Date().ISO8601Format()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url)
            return url
        } catch {
            handle(error: error)
            return nil
        }
    }
    
    // MARK: - Mock Data
    
    #if DEBUG
    func loadMockData() {
        let mockMetrics = HealthMetric.generateMockData(days: 30)
        metricsState = .loaded(mockMetrics)
        syncState = .loaded(.synced)
    }
    #endif
}

// MARK: - Supporting Types

enum DateRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "Year"
    
    func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: endDate)!
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate)!
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate)!
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: endDate)!
        }
    }
}

// MARK: - HealthMetric Mock Data

#if DEBUG
extension HealthMetric {
    static func generateMockData(days: Int) -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let calendar = Calendar.current
        let endDate = Date()
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) else { continue }
            
            // Steps
            let steps = HealthMetric(
                type: .steps,
                value: Double.random(in: 5000...15000),
                unit: "steps",
                date: date,
                source: .manual
            )
            metrics.append(steps)
            
            // Heart Rate
            let heartRate = HealthMetric(
                type: .heartRate,
                value: Double.random(in: 60...80),
                unit: "bpm",
                date: date,
                source: .manual
            )
            metrics.append(heartRate)
            
            // Sleep
            let sleep = HealthMetric(
                type: .sleep,
                value: Double.random(in: 6...9),
                unit: "hours",
                date: date,
                source: .manual,
                metadata: [
                    "efficiency": "\(Double.random(in: 0.7...0.95))",
                    "timeInBed": "\(Double.random(in: 7...10) * 3600)"
                ]
            )
            metrics.append(sleep)
        }
        
        return metrics
    }
}
#endif