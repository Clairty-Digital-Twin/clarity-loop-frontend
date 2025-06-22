# Phase 3: Health Data Sync Fix Implementation Plan

## Problem Summary
HealthKit authorization works but no actual health data syncs to the backend or displays in the app.

## Root Causes
1. Health upload endpoints are untested/unknown format
2. Background sync is registered but never executes
3. No incremental sync strategy (tries to upload everything)
4. Dashboard shows empty state even when data exists

## Fix Implementation Steps

### Step 1: Implement Basic Health Data Upload
**File**: `/Core/Services/HealthKitService.swift`

First, test what format the backend expects:

```swift
// Add debug upload method
func testHealthUpload() async throws {
    // Create minimal test data
    let testMetric = HealthKitUploadRequestDTO(
        metrics: [
            HealthMetricUploadDTO(
                metricType: "steps",
                value: 1000.0,
                unit: "count",
                timestamp: Date(),
                source: "Apple Watch",
                metadata: [:]
            )
        ],
        deviceInfo: DeviceInfoHelper.generateDeviceInfo(),
        uploadBatchId: UUID().uuidString,
        isBackgroundUpload: false
    )
    
    print("📤 Testing health upload with: \(testMetric)")
    let response = try await apiClient.uploadHealthKitData(requestDTO: testMetric)
    print("✅ Upload response: \(response)")
}
```

### Step 2: Fix Data Fetching from HealthKit
**File**: `/Core/Services/HealthKitService.swift`

Ensure we're actually getting data:

```swift
// Update fetchStepCount to include more detail
func fetchStepCount(for date: Date) async throws -> Double {
    print("📊 Fetching steps for date: \(date)")
    
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
    )
    
    let steps = try await queryHealthKit(
        for: stepType,
        predicate: predicate,
        options: [.cumulativeSum]
    )
    
    print("📊 Found \(steps) steps for \(date)")
    return steps
}
```

### Step 3: Implement Batch Upload Strategy
**File**: Create `/Core/Services/HealthDataUploadService.swift`

```swift
import Foundation
import HealthKit

@MainActor
final class HealthDataUploadService {
    private let healthKitService: HealthKitServiceProtocol
    private let apiClient: APIClientProtocol
    private let storage: UserDefaults
    
    private let batchSize = 100
    private let uploadInterval: TimeInterval = 300 // 5 minutes
    
    init(
        healthKitService: HealthKitServiceProtocol,
        apiClient: APIClientProtocol,
        storage: UserDefaults = .standard
    ) {
        self.healthKitService = healthKitService
        self.apiClient = apiClient
        self.storage = storage
    }
    
    func performIncrementalSync() async throws {
        let lastSyncDate = storage.object(forKey: "lastHealthSyncDate") as? Date ?? Date().addingTimeInterval(-86400) // Default to 24 hours ago
        let now = Date()
        
        print("🔄 Syncing health data from \(lastSyncDate) to \(now)")
        
        // Fetch data in batches
        var allMetrics: [HealthMetricUploadDTO] = []
        
        // Fetch different metric types
        let steps = try await fetchStepMetrics(from: lastSyncDate, to: now)
        allMetrics.append(contentsOf: steps)
        
        let heartRate = try await fetchHeartRateMetrics(from: lastSyncDate, to: now)
        allMetrics.append(contentsOf: heartRate)
        
        // Upload in batches
        for chunk in allMetrics.chunked(into: batchSize) {
            try await uploadBatch(chunk)
        }
        
        // Update last sync date
        storage.set(now, forKey: "lastHealthSyncDate")
        print("✅ Health sync completed")
    }
    
    private func fetchStepMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthMetricUploadDTO] {
        // Implementation here
    }
    
    private func uploadBatch(_ metrics: [HealthMetricUploadDTO]) async throws {
        let request = HealthKitUploadRequestDTO(
            metrics: metrics,
            deviceInfo: DeviceInfoHelper.generateDeviceInfo(),
            uploadBatchId: UUID().uuidString,
            isBackgroundUpload: false
        )
        
        _ = try await apiClient.uploadHealthKitData(requestDTO: request)
    }
}
```

### Step 4: Fix Background Task Execution
**File**: `/Core/Services/BackgroundTaskManager.swift`

Make background tasks actually run:

```swift
func handleHealthDataSync() async {
    print("🔄 Background health sync started")
    
    do {
        // Get current user
        guard let userId = ServiceLocator.shared.currentUserId else {
            print("❌ No user ID for background sync")
            return
        }
        
        // Perform incremental sync
        let uploadService = HealthDataUploadService(
            healthKitService: ServiceLocator.shared.healthKitService!,
            apiClient: ServiceLocator.shared.apiClient!
        )
        
        try await uploadService.performIncrementalSync()
        
        print("✅ Background health sync completed")
    } catch {
        print("❌ Background health sync failed: \(error)")
    }
}
```

### Step 5: Fix Dashboard Data Loading
**File**: `/Features/Dashboard/DashboardViewModel.swift`

Ensure dashboard shows real data:

```swift
func loadDashboard() async {
    viewState = .loading
    
    do {
        // Request HealthKit authorization
        try await healthKitService.requestAuthorization()
        
        // Fetch today's metrics
        let metrics = try await healthKitService.fetchAllDailyMetrics(for: Date())
        
        print("📊 Dashboard metrics loaded:")
        print("  Steps: \(metrics.stepCount)")
        print("  Heart Rate: \(metrics.restingHeartRate ?? 0)")
        print("  Sleep: \(metrics.sleepData?.totalSleepMinutes ?? 0) minutes")
        
        // Try to get insights (but don't fail if none)
        let userId = await authService.currentUser?.id ?? "unknown"
        let insights = try? await insightsRepo.getInsightHistory(userId: userId, limit: 1, offset: 0)
        
        let data = DashboardData(
            metrics: metrics,
            insightOfTheDay: insights?.data.insights.first
        )
        
        // Show data even if only partial
        if metrics.stepCount > 0 || metrics.restingHeartRate != nil || metrics.sleepData != nil {
            viewState = .loaded(data)
        } else {
            viewState = .empty
        }
    } catch {
        print("❌ Dashboard load error: \(error)")
        viewState = .error(error)
    }
}
```

### Step 6: Add Manual Sync for Testing
**File**: `/Features/Settings/SettingsViewModel.swift`

Update sync button to actually work:

```swift
func syncHealthData() async {
    isLoading = true
    errorMessage = nil
    
    do {
        let uploadService = HealthDataUploadService(
            healthKitService: healthKitService,
            apiClient: ServiceLocator.shared.apiClient!
        )
        
        try await uploadService.performIncrementalSync()
        
        lastSyncDate = Date()
        successMessage = "Health data synced successfully"
    } catch {
        errorMessage = "Sync failed: \(error.localizedDescription)"
    }
    
    isLoading = false
}
```

### Step 7: Add Sync Status UI
**File**: Create `/UI/Components/SyncStatusView.swift`

```swift
import SwiftUI

struct SyncStatusView: View {
    let lastSyncDate: Date?
    let isSyncing: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .foregroundColor(isSyncing ? .orange : .green)
                .symbolEffect(.rotate, isActive: isSyncing)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isSyncing ? "Syncing..." : "Synced")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let date = lastSyncDate {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
```

## Testing Plan

1. **Test Manual Upload**
   - Add test button to upload single metric
   - Verify backend accepts format
   - Check response format

2. **Test Incremental Sync**
   - Sync 1 day of data
   - Verify only new data uploads
   - Check for duplicates

3. **Test Background Sync**
   - Enable background delivery
   - Make changes in Health app
   - Verify auto-upload works

4. **Test Dashboard Display**
   - Sync data
   - Verify shows in dashboard
   - Test empty states

## Success Criteria
- [ ] Health data uploads successfully
- [ ] Dashboard shows real metrics
- [ ] Background sync works
- [ ] Incremental sync prevents duplicates
- [ ] Sync status visible to user

## Estimated Time: 3-4 Days

## Next Phase
Once health sync works, move to Phase 4: UI/UX Polish

---

*This plan depends on backend endpoint documentation*