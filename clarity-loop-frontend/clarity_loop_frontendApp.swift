import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import BackgroundTasks
import SwiftData
import SwiftUI
#if canImport(UIKit) && DEBUG
    import UIKit
#endif

@main
struct ClarityPulseApp: App {
    // MARK: - Properties
    
    /// Detects if running in test environment using runtime checks
    private static var isRunningInTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil ||
        Bundle.main.bundlePath.hasSuffix(".xctest") ||
        ProcessInfo.processInfo.processName.contains("Test")
    }

    // By using the @State property wrapper, we ensure that the AuthViewModel
    // is instantiated only once for the entire lifecycle of the app.
    @State private var authViewModel: AuthViewModel

    // The APIClient and services are instantiated here and injected into the environment.
    private let authService: AuthServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let apiClient: APIClientProtocol
    private let insightsRepository: InsightsRepositoryProtocol
    private let healthDataRepository: HealthDataRepositoryProtocol
    private let backgroundTaskManager: BackgroundTaskManagerProtocol
    private let offlineQueueManager: OfflineQueueManagerProtocol

    // MARK: - Initializer

    init() {
        // Configure Amplify, but skip during test execution to prevent crashes
        if !Self.isRunningInTestEnvironment {
            AmplifyConfigurator.configure()
        }
        
        // Initialize the BackendAPIClient with proper token provider
        // Use safe fallback for background launch compatibility
        let client: APIClientProtocol
        if
            let backendClient = BackendAPIClient(tokenProvider: {
                print("🔍 APP: Token provider called")

                // Skip Amplify Auth during tests to prevent crashes
                if Self.isRunningInTestEnvironment {
                    print("🧪 APP: Running in test mode - returning mock token")
                    return "mock-test-token"
                }

                // Use Amplify Auth to get token
                do {
                    let authSession = try await Amplify.Auth.fetchAuthSession()
                    
                    if let cognitoTokenProvider = authSession as? AuthCognitoTokensProvider {
                        let tokens = try cognitoTokenProvider.getCognitoTokens().get()
                        let token = tokens.accessToken
                        
                        print("✅ APP: Token obtained from Amplify Auth")
                        print("   - Length: \(token.count)")

                        #if DEBUG
                            // Print the full JWT so we can copy from the console
                            print("🧪 FULL_ACCESS_TOKEN → \(token)")

                            // Copy to clipboard for CLI use
                            #if canImport(UIKit)
                                UIPasteboard.general.string = token
                                print("📋 Token copied to clipboard")
                            #endif
                        #endif
                        
                        return token
                    }
                } catch {
                    print("⚠️ APP: Failed to get token from Amplify: \(error)")
                }
                
                return nil
            }) {
            client = backendClient
        } else {
            print("⚠️ APP: Failed to initialize BackendAPIClient, using fallback DummyAPIClient")
            // Fallback to dummy client instead of crashing
            client = DummyAPIClient()
        }

        self.apiClient = client

        // Initialize services with shared APIClient
        let service = AuthService(apiClient: client)
        self.authService = service

        // TokenManagementService no longer needed - using Amplify Auth

        let healthKit = HealthKitService(apiClient: client)
        self.healthKitService = healthKit

        // Initialize repositories with shared APIClient
        self.insightsRepository = RemoteInsightsRepository(apiClient: client)
        self.healthDataRepository = RemoteHealthDataRepository(apiClient: client)

        // Initialize service locator for background tasks
        ServiceLocator.shared.healthKitService = healthKitService
        ServiceLocator.shared.healthDataRepository = healthDataRepository
        ServiceLocator.shared.insightsRepository = insightsRepository

        // Initialize background task manager
        self.backgroundTaskManager = BackgroundTaskManager(
            healthKitService: healthKitService,
            healthDataRepository: healthDataRepository
        )

        // Register background tasks
        backgroundTaskManager.registerBackgroundTasks()

        // Initialize offline queue manager
        let queueManager = OfflineQueueManager(
            modelContext: PersistenceController.shared.container.mainContext,
            healthDataRepository: healthDataRepository,
            insightsRepository: insightsRepository
        )
        self.offlineQueueManager = queueManager

        // Connect offline queue manager to HealthKitService
        healthKit.setOfflineQueueManager(queueManager)

        // Start offline queue monitoring
        offlineQueueManager.startMonitoring()

        // The AuthViewModel is created with the concrete AuthService instance.
        _authViewModel = State(initialValue: AuthViewModel(authService: service))
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppRootView(
                authService: authService,
                backgroundTaskManager: backgroundTaskManager
            )
            .onAppear {
                print("🔥 APP ROOT APPEARED")
                print("🔥 ENVIRONMENT AVAILABLE: AuthService type = \(type(of: authService))")
            }
            .modelContainer(PersistenceController.shared.container)
            .environment(authViewModel)
            .environment(\.authService, authService)
            .environment(\.healthKitService, healthKitService)
            .environment(\.apiClient, apiClient)
            .environment(\.insightsRepository, insightsRepository)
            .environment(\.healthDataRepository, healthDataRepository)
        }
    }
}

// MARK: - App Root View with Lifecycle Management

private struct AppRootView: View {
    let authService: AuthServiceProtocol
    let backgroundTaskManager: BackgroundTaskManagerProtocol

    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ContentView()
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Schedule background tasks when app enters background
                backgroundTaskManager.scheduleHealthDataSync()
                backgroundTaskManager.scheduleAppRefresh()
            }
            .onChange(of: authViewModel.isLoggedIn) { _, newValue in
                // Update service locator with current user ID
                if newValue {
                    Task {
                        if let currentUser = await authService.currentUser {
                            ServiceLocator.shared.currentUserId = currentUser.id
                        }
                    }
                } else {
                    ServiceLocator.shared.currentUserId = nil
                }
            }
    }
}