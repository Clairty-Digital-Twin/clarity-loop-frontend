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
            
            // If no type selected, fetch all types
            let metrics: [HealthMetric]
            if let type = selectedMetricType {
                metrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
            } else {
                // Fetch all types
                var allMetrics: [HealthMetric] = []
                for type in HealthMetricType.allCases {
                    let typeMetrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
                    allMetrics.append(contentsOf: typeMetrics)
                }
                metrics = allMetrics
            }
            
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
                    let stepMetric = HealthMetric()
                    stepMetric.type = .steps
                    stepMetric.value = Double(metrics.stepCount)
                    stepMetric.unit = "steps"
                    stepMetric.timestamp = date
                    stepMetric.source = "HealthKit"
                    healthMetrics.append(stepMetric)
                }
                
                // Heart Rate
                if let heartRate = metrics.restingHeartRate {
                    let heartMetric = HealthMetric()
                    heartMetric.type = .heartRate
                    heartMetric.value = heartRate
                    heartMetric.unit = "bpm"
                    heartMetric.timestamp = date
                    heartMetric.source = "HealthKit"
                    healthMetrics.append(heartMetric)
                }
                
                // Sleep
                if let sleepData = metrics.sleepData {
                    let sleepMetric = HealthMetric()
                    sleepMetric.type = .sleepDuration
                    sleepMetric.value = sleepData.totalTimeAsleep / 3600 // Convert to hours
                    sleepMetric.unit = "hours"
                    sleepMetric.timestamp = date
                    sleepMetric.source = "HealthKit"
                    sleepMetric.metadata = [
                        "efficiency": "\(sleepData.sleepEfficiency)",
                        "timeInBed": "\(sleepData.totalTimeInBed)"
                    ]
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
            let steps = HealthMetric()
            steps.type = .steps
            steps.value = Double.random(in: 5000...15000)
            steps.unit = "steps"
            steps.timestamp = date
            steps.source = "Manual"
            metrics.append(steps)
            
            // Heart Rate
            let heartRate = HealthMetric()
            heartRate.type = .heartRate
            heartRate.value = Double.random(in: 60...80)
            heartRate.unit = "bpm"
            heartRate.timestamp = date
            heartRate.source = "Manual"
            metrics.append(heartRate)
            
            // Sleep
            let sleep = HealthMetric()
            sleep.type = .sleepDuration
            sleep.value = Double.random(in: 6...9)
            sleep.unit = "hours"
            sleep.timestamp = date
            sleep.source = "Manual"
            sleep.metadata = [
                "efficiency": "\(Double.random(in: 0.7...0.95))",
                "timeInBed": "\(Double.random(in: 7...10) * 3600)"
            ]
            metrics.append(sleep)
        }
        
        return metrics
    }
}
#endif