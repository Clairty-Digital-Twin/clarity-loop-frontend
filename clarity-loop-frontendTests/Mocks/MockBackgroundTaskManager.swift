@testable import clarity_loop_frontend
import Foundation

// Mock implementation of BackgroundTaskManagerProtocol for testing
class MockBackgroundTaskManager: BackgroundTaskManagerProtocol {
    // MARK: - Control Properties
    
    var shouldFail = false
    var mockError = BackgroundTaskError.taskFailed
    
    // Tracking properties
    var registerCalled = false
    var healthDataSyncScheduled = false
    var appRefreshScheduled = false
    var processingSyncScheduled = false
    var taskCompletions: [String: Bool] = [:]
    
    // MARK: - BackgroundTaskManagerProtocol Requirements
    
    func registerBackgroundTasks() {
        registerCalled = true
    }
    
    func scheduleHealthDataSync() {
        healthDataSyncScheduled = true
    }
    
    func scheduleAppRefresh() {
        appRefreshScheduled = true
    }
    
    func scheduleProcessingSync() {
        processingSyncScheduled = true
    }
    
    func handleHealthDataSync(task: @escaping (Bool) -> Void) async {
        if shouldFail {
            task(false)
            taskCompletions["healthDataSync"] = false
        } else {
            // Simulate successful sync
            task(true)
            taskCompletions["healthDataSync"] = true
        }
    }
    
    func handleAppRefresh(task: @escaping (Bool) -> Void) async {
        if shouldFail {
            task(false)
            taskCompletions["appRefresh"] = false
        } else {
            // Simulate successful refresh
            task(true)
            taskCompletions["appRefresh"] = true
        }
    }
    
    // Helper method to reset state
    func reset() {
        registerCalled = false
        healthDataSyncScheduled = false
        appRefreshScheduled = false
        processingSyncScheduled = false
        taskCompletions.removeAll()
        shouldFail = false
    }
}

enum BackgroundTaskError: Error {
    case taskFailed
    case registrationFailed
}