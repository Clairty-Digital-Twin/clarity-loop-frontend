import Foundation
import Observation
import SwiftUI

/// A struct to hold all the necessary data for the dashboard.
/// This will be expanded as more data sources are integrated.
struct DashboardData: Equatable {
    let metrics: DailyHealthMetrics
    let insightOfTheDay: InsightPreviewDTO?
}

@Observable
final class DashboardViewModel {
    // MARK: - Properties

    var viewState: ViewState<DashboardData> = .idle

    // MARK: - Dependencies

    private let insightsRepo: InsightsRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let authService: AuthServiceProtocol

    // MARK: - Initializer

    init(
        insightsRepo: InsightsRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.insightsRepo = insightsRepo
        self.healthKitService = healthKitService
        self.authService = authService
    }

    // MARK: - Public Methods

    /// Loads all necessary data for the dashboard.
    func loadDashboard() async {
        viewState = .loading

        do {
            // Try to request HealthKit authorization, but don't fail if denied
            var dailyMetrics: DailyHealthMetrics
            do {
                try await healthKitService.requestAuthorization()
                dailyMetrics = try await healthKitService.fetchAllDailyMetrics(for: Date())
            } catch {
                print("HealthKit access failed, using default metrics: \(error)")
                // Fallback to empty metrics if HealthKit fails
                dailyMetrics = DailyHealthMetrics(
                    date: Date(),
                    stepCount: 0,
                    restingHeartRate: nil,
                    sleepData: nil
                )
            }

            // Try to fetch insights, but don't fail if API is down
            var insightOfTheDay: InsightPreviewDTO?
            do {
                let userId = await authService.currentUser?.id ?? "unknown"
                let insightsResponse = try await insightsRepo.getInsightHistory(userId: userId, limit: 1, offset: 0)
                insightOfTheDay = insightsResponse.data.insights.first
            } catch {
                print("Insights API failed, continuing without insights: \(error)")
                insightOfTheDay = nil
            }

            let data = DashboardData(metrics: dailyMetrics, insightOfTheDay: insightOfTheDay)

            // Show the dashboard even if we only have partial data
            viewState = .loaded(data)
            
        } catch {
            // Only fail if something truly unexpected happens
            viewState = .error(error)
        }
    }

    #if targetEnvironment(simulator)
        /// Loads sample data for simulator testing
        func loadSampleData() async {
            viewState = .loading

            // Create sample data for simulator
            let sampleMetrics = DailyHealthMetrics(
                date: Date(),
                stepCount: 8247,
                restingHeartRate: 65.0,
                sleepData: SleepData(
                    totalTimeInBed: 28800, // 8 hours
                    totalTimeAsleep: 25200, // 7 hours
                    sleepEfficiency: 0.875
                )
            )

            let sampleInsight: InsightPreviewDTO? = InsightPreviewDTO(
                id: UUID().uuidString,
                narrative: "You achieved 7 hours of sleep with 87.5% efficiency. This is excellent for recovery and cognitive function. Your resting heart rate of 65 BPM indicates good cardiovascular fitness.",
                generatedAt: Date(),
                confidenceScore: 0.92,
                keyInsightsCount: 2,
                recommendationsCount: 1
            )

            let data = DashboardData(
                metrics: sampleMetrics,
                insightOfTheDay: sampleInsight
            )

            // Small delay to simulate loading
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            viewState = .loaded(data)
        }
    #endif
}
