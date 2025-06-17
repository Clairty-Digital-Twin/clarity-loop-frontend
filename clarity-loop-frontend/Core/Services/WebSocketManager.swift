import Foundation
import Combine
import Network
import UIKit

/// Manages WebSocket connections for real-time updates
@MainActor
final class WebSocketManager: ObservableObject {
    // MARK: - Properties
    
    static let shared = WebSocketManager()
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: WebSocketError?
    @Published private(set) var receivedMessages: [WebSocketMessage] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let authService: AuthServiceProtocol
    private let eventProcessor: WebSocketEventProcessor
    
    private var cancellables = Set<AnyCancellable>()
    private var messageHandlers: [MessageType: [MessageHandler]] = [:]
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    
    // MARK: - Configuration
    
    private let webSocketURL: URL
    private let reconnectDelay: TimeInterval = 5.0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let pingInterval: TimeInterval = 30.0
    private var currentReconnectDelay: TimeInterval = 5.0
    
    // MARK: - Subjects for broadcasting events
    
    let healthMetricUpdates = PassthroughSubject<HealthMetricUpdate, Never>()
    let insightNotifications = PassthroughSubject<InsightNotification, Never>()
    let patAnalysisUpdates = PassthroughSubject<PATAnalysisUpdate, Never>()
    let syncStatusUpdates = PassthroughSubject<SyncStatusUpdate, Never>()
    let systemNotifications = PassthroughSubject<SystemNotification, Never>()
    
    // MARK: - Initialization
    
    private init(
        baseURL: String = "wss://clarity.novamindnyc.com",
        authService: AuthServiceProtocol? = nil
    ) {
        self.webSocketURL = URL(string: "\(baseURL)/ws")!
        self.authService = authService ?? AuthService.shared
        self.eventProcessor = WebSocketEventProcessor()
        
        setupAuthObserver()
        setupHandlers()
    }
    
    // MARK: - Public Methods
    
    /// Connect to WebSocket server
    func connect() async {
        guard connectionState == .disconnected else { return }
        
        connectionState = .connecting
        lastError = nil
        
        do {
            // Get auth token
            guard let token = try await authService.getAuthToken() else {
                throw WebSocketError.authenticationRequired
            }
            
            // Create WebSocket request
            var request = URLRequest(url: webSocketURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("clarity-ios-app", forHTTPHeaderField: "X-Client-Type")
            request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Client-ID")
            
            // Configure session
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 300
            
            urlSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: .main)
            webSocketTask = urlSession?.webSocketTask(with: request)
            
            // Start connection
            webSocketTask?.resume()
            
            // Start receiving messages
            startReceiving()
            
            // Send initial handshake
            await sendHandshake()
            
            connectionState = .connected
            currentReconnectDelay = reconnectDelay
            
            // Start ping timer
            startPingTimer()
            
        } catch {
            connectionState = .disconnected
            lastError = error as? WebSocketError ?? .connectionFailed(error)
            scheduleReconnect()
        }
    }
    
    /// Disconnect from WebSocket server
    func disconnect() {
        guard connectionState != .disconnected else { return }
        
        connectionState = .disconnecting
        
        // Cancel timers
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // Close WebSocket
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        
        connectionState = .disconnected
    }
    
    /// Send a message through WebSocket
    func send<T: Encodable>(_ message: T, type: MessageType) async throws {
        guard connectionState == .connected else {
            throw WebSocketError.notConnected
        }
        
        let wrapper = WebSocketMessage(
            id: UUID().uuidString,
            type: type,
            timestamp: Date(),
            payload: try JSONEncoder().encode(message)
        )
        
        let data = try JSONEncoder().encode(wrapper)
        let message = URLSessionWebSocketTask.Message.data(data)
        
        try await webSocketTask?.send(message)
    }
    
    /// Subscribe to specific message type
    func subscribe(to type: MessageType, handler: @escaping MessageHandler) -> AnyCancellable {
        if messageHandlers[type] == nil {
            messageHandlers[type] = []
        }
        
        let id = UUID()
        let wrapper = HandlerWrapper(id: id, handler: handler)
        messageHandlers[type]?.append(wrapper)
        
        return AnyCancellable { [weak self] in
            self?.messageHandlers[type]?.removeAll { ($0 as? HandlerWrapper)?.id == id }
        }
    }
    
    /// Request specific data updates
    func requestHealthMetrics(since: Date) async throws {
        let request = HealthMetricsRequest(
            userId: await authService.currentUser?.id ?? "",
            since: since,
            types: HealthMetricType.allCases.map { $0.rawValue }
        )
        
        try await send(request, type: .healthMetricsRequest)
    }
    
    func requestInsightUpdate(insightId: String) async throws {
        let request = InsightUpdateRequest(insightId: insightId)
        try await send(request, type: .insightUpdateRequest)
    }
    
    // MARK: - Private Methods
    
    private func setupAuthObserver() {
        // Observe auth state changes
        NotificationCenter.default.publisher(for: .authStateChanged)
            .sink { [weak self] _ in
                Task {
                    if await self?.authService.isAuthenticated == true {
                        await self?.connect()
                    } else {
                        self?.disconnect()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupHandlers() {
        // Setup message type handlers
        subscribe(to: .healthMetricUpdate) { [weak self] message in
            if let update = try? JSONDecoder().decode(HealthMetricUpdate.self, from: message.payload) {
                self?.healthMetricUpdates.send(update)
            }
        }.store(in: &cancellables)
        
        subscribe(to: .insightNotification) { [weak self] message in
            if let notification = try? JSONDecoder().decode(InsightNotification.self, from: message.payload) {
                self?.insightNotifications.send(notification)
            }
        }.store(in: &cancellables)
        
        subscribe(to: .patAnalysisUpdate) { [weak self] message in
            if let update = try? JSONDecoder().decode(PATAnalysisUpdate.self, from: message.payload) {
                self?.patAnalysisUpdates.send(update)
            }
        }.store(in: &cancellables)
        
        subscribe(to: .syncStatusUpdate) { [weak self] message in
            if let update = try? JSONDecoder().decode(SyncStatusUpdate.self, from: message.payload) {
                self?.syncStatusUpdates.send(update)
            }
        }.store(in: &cancellables)
        
        subscribe(to: .systemNotification) { [weak self] message in
            if let notification = try? JSONDecoder().decode(SystemNotification.self, from: message.payload) {
                self?.systemNotifications.send(notification)
            }
        }.store(in: &cancellables)
    }
    
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    await self.handleMessage(message)
                    // Continue receiving
                    if self.connectionState == .connected {
                        self.startReceiving()
                    }
                    
                case .failure(let error):
                    self.handleError(error)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            await processData(data)
            
        case .string(let text):
            if let data = text.data(using: .utf8) {
                await processData(data)
            }
            
        @unknown default:
            break
        }
    }
    
    private func processData(_ data: Data) async {
        do {
            let message = try JSONDecoder().decode(WebSocketMessage.self, from: data)
            
            // Store recent messages
            receivedMessages.append(message)
            if receivedMessages.count > 100 {
                receivedMessages.removeFirst()
            }
            
            // Process based on type
            await eventProcessor.process(message)
            
            // Notify handlers
            if let handlers = messageHandlers[message.type] {
                for handler in handlers {
                    handler.handler(message)
                }
            }
            
        } catch {
            print("Failed to decode WebSocket message: \(error)")
        }
    }
    
    private func handleError(_ error: Error) {
        lastError = .connectionLost(error)
        
        if connectionState == .connected {
            connectionState = .disconnected
            scheduleReconnect()
        }
    }
    
    private func sendHandshake() async {
        let handshake = HandshakeMessage(
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            platform: "iOS",
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
        
        try? await send(handshake, type: .handshake)
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.sendPing()
            }
        }
    }
    
    private func sendPing() async {
        guard connectionState == .connected else { return }
        
        let ping = PingMessage(timestamp: Date())
        try? await send(ping, type: .ping)
    }
    
    private func scheduleReconnect() {
        guard reconnectTimer == nil else { return }
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: currentReconnectDelay, repeats: false) { [weak self] _ in
            self?.reconnectTimer = nil
            Task {
                await self?.connect()
            }
        }
        
        // Exponential backoff
        currentReconnectDelay = min(currentReconnectDelay * 2, maxReconnectDelay)
    }
}

// MARK: - Supporting Types

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

enum MessageType: String, Codable {
    // Control messages
    case handshake
    case ping
    case pong
    case error
    
    // Data messages
    case healthMetricUpdate
    case insightNotification
    case patAnalysisUpdate
    case syncStatusUpdate
    case systemNotification
    
    // Request messages
    case healthMetricsRequest
    case insightUpdateRequest
    case subscribeRequest
    case unsubscribeRequest
}

struct WebSocketMessage: Codable {
    let id: String
    let type: MessageType
    let timestamp: Date
    let payload: Data
}

typealias MessageHandler = (WebSocketMessage) -> Void

private struct HandlerWrapper: MessageHandler {
    let id: UUID
    let handler: MessageHandler
    
    func callAsFunction(_ message: WebSocketMessage) {
        handler(message)
    }
}

// MARK: - Message Types

struct HandshakeMessage: Codable {
    let clientVersion: String
    let platform: String
    let deviceId: String
}

struct PingMessage: Codable {
    let timestamp: Date
}

struct HealthMetricsRequest: Codable {
    let userId: String
    let since: Date
    let types: [String]
}

struct InsightUpdateRequest: Codable {
    let insightId: String
}

// MARK: - Update Types

struct HealthMetricUpdate: Codable {
    let metricId: String
    let type: String
    let value: Double
    let unit: String
    let timestamp: Date
    let source: String
}

struct InsightNotification: Codable {
    let insightId: String
    let title: String
    let message: String
    let priority: String
    let timestamp: Date
}

struct PATAnalysisUpdate: Codable {
    let analysisId: String
    let status: String
    let progress: Double
    let results: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case analysisId, status, progress, results
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analysisId = try container.decode(String.self, forKey: .analysisId)
        status = try container.decode(String.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        
        if let resultsData = try? container.decode([String: WebSocketAnyCodable].self, forKey: .results) {
            results = resultsData.mapValues { $0.value }
        } else {
            results = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(analysisId, forKey: .analysisId)
        try container.encode(status, forKey: .status)
        try container.encode(progress, forKey: .progress)
        
        if let results = results {
            let codableResults = results.mapValues { WebSocketAnyCodable($0) }
            try container.encode(codableResults, forKey: .results)
        }
    }
}

struct SyncStatusUpdate: Codable {
    let entityType: String
    let entityId: String
    let syncStatus: String
    let timestamp: Date
    let details: String?
}

struct SystemNotification: Codable {
    let id: String
    let type: SystemNotificationType
    let title: String
    let message: String
    let timestamp: Date
    let actions: [NotificationAction]?
}

enum SystemNotificationType: String, Codable {
    case maintenance
    case update
    case feature
    case alert
    case promotion
}

struct NotificationAction: Codable {
    let id: String
    let title: String
    let type: ActionType
    let data: [String: String]?
}

enum ActionType: String, Codable {
    case navigate
    case dismiss
    case custom
}

// MARK: - Event Processor

@MainActor
final class WebSocketEventProcessor {
    private let healthRepository: HealthRepository
    private let insightRepository: AIInsightRepository
    private let patRepository: PATAnalysisRepository
    
    init() {
        let modelContext = SwiftDataConfigurator.shared.container.mainContext
        self.healthRepository = HealthRepository(modelContext: modelContext)
        self.insightRepository = AIInsightRepository(modelContext: modelContext)
        self.patRepository = PATAnalysisRepository(modelContext: modelContext)
    }
    
    func process(_ message: WebSocketMessage) async {
        switch message.type {
        case .healthMetricUpdate:
            await processHealthMetricUpdate(message)
        case .insightNotification:
            await processInsightNotification(message)
        case .patAnalysisUpdate:
            await processPATUpdate(message)
        case .syncStatusUpdate:
            await processSyncStatusUpdate(message)
        default:
            break
        }
    }
    
    private func processHealthMetricUpdate(_ message: WebSocketMessage) async {
        guard let update = try? JSONDecoder().decode(HealthMetricUpdate.self, from: message.payload) else { return }
        
        // Update local database
        if let type = HealthMetricType(rawValue: update.type) {
            let metric = HealthMetric()
            metric.localID = UUID(uuidString: update.metricId) ?? UUID()
            metric.type = type
            metric.value = update.value
            metric.unit = update.unit
            metric.timestamp = update.timestamp
            metric.source = update.source
            metric.syncStatus = .synced
            metric.lastSyncedAt = Date()
            
            try? await healthRepository.create(metric)
        }
    }
    
    private func processInsightNotification(_ message: WebSocketMessage) async {
        guard let notification = try? JSONDecoder().decode(InsightNotification.self, from: message.payload) else { return }
        
        // Update insight if it exists
        if let insight = try? await insightRepository.fetchByInsightId(notification.insightId) {
            insight.isRead = false
            insight.updatedAt = Date()
            try? await insightRepository.update(insight)
        }
    }
    
    private func processPATUpdate(_ message: WebSocketMessage) async {
        guard let update = try? JSONDecoder().decode(PATAnalysisUpdate.self, from: message.payload) else { return }
        
        // Update PAT analysis
        if let analysis = try? await patRepository.fetchById(update.analysisId) {
            if let status = PATAnalysisStatus(rawValue: update.status) {
                analysis.status = status
            }
            analysis.completionPercentage = update.progress
            analysis.lastModified = Date()
            
            try? await patRepository.update(analysis)
        }
    }
    
    private func processSyncStatusUpdate(_ message: WebSocketMessage) async {
        guard let update = try? JSONDecoder().decode(SyncStatusUpdate.self, from: message.payload) else { return }
        
        // Update sync status based on entity type
        switch update.entityType {
        case "HealthMetric":
            // Update health metric sync status
            break
        case "AIInsight":
            // Update insight sync status
            break
        case "PATAnalysis":
            // Update PAT sync status
            break
        default:
            break
        }
    }
}

// MARK: - Errors

enum WebSocketError: LocalizedError {
    case authenticationRequired
    case connectionFailed(Error)
    case connectionLost(Error)
    case notConnected
    case invalidMessage
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required for WebSocket connection"
        case .connectionFailed(let error):
            return "Failed to connect: \(error.localizedDescription)"
        case .connectionLost(let error):
            return "Connection lost: \(error.localizedDescription)"
        case .notConnected:
            return "WebSocket is not connected"
        case .invalidMessage:
            return "Invalid WebSocket message format"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - WebSocketAnyCodable Helper

struct WebSocketAnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([WebSocketAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: WebSocketAnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { WebSocketAnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { WebSocketAnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
    static let webSocketConnected = Notification.Name("webSocketConnected")
    static let webSocketDisconnected = Notification.Name("webSocketDisconnected")
}