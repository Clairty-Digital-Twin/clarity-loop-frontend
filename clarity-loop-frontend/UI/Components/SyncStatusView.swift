import SwiftUI

/// A reusable view component that displays health data sync status
struct SyncStatusView: View {
    let isSyncing: Bool
    let lastSyncDate: Date?
    let syncError: Error?
    let syncProgress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Health Sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                Spacer()
                statusIcon
            }
            
            // Progress or Status
            if isSyncing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Syncing health data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(syncProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: syncProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            } else if let error = syncError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync failed")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            } else if let lastSync = lastSyncDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last synced")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lastSync, style: .relative)
                        .font(.subheadline)
                }
            } else {
                Text("Not synced yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isSyncing {
            ProgressView()
                .scaleEffect(0.8)
        } else if syncError != nil {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        } else if lastSyncDate != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.gray)
        }
    }
    
    private var backgroundGradient: LinearGradient {
        if isSyncing {
            return LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if syncError != nil {
            return LinearGradient(
                colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderColor: Color {
        if isSyncing {
            return .blue.opacity(0.3)
        } else if syncError != nil {
            return .red.opacity(0.3)
        } else if lastSyncDate != nil {
            return .green.opacity(0.3)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Convenience Initializer

extension SyncStatusView {
    /// Initialize with a HealthDataSyncManager
    init(syncManager: HealthDataSyncManager) {
        self.init(
            isSyncing: syncManager.isSyncing,
            lastSyncDate: syncManager.lastSyncDate,
            syncError: syncManager.syncError,
            syncProgress: syncManager.syncProgress
        )
    }
}

// MARK: - Preview

#Preview("Syncing") {
    SyncStatusView(
        isSyncing: true,
        lastSyncDate: nil,
        syncError: nil,
        syncProgress: 0.65
    )
    .padding()
}

#Preview("Success") {
    SyncStatusView(
        isSyncing: false,
        lastSyncDate: Date().addingTimeInterval(-3600),
        syncError: nil,
        syncProgress: 1.0
    )
    .padding()
}

#Preview("Error") {
    SyncStatusView(
        isSyncing: false,
        lastSyncDate: Date().addingTimeInterval(-7200),
        syncError: APIError.serverError(statusCode: 500, message: "Server error"),
        syncProgress: 0.0
    )
    .padding()
}

#Preview("Never Synced") {
    SyncStatusView(
        isSyncing: false,
        lastSyncDate: nil,
        syncError: nil,
        syncProgress: 0.0
    )
    .padding()
}