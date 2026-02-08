import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {

    enum TimelineItem: Identifiable {
        case message(Message)
        case task(AgentTask)

        var id: String {
            switch self {
            case .message(let message):
                return "message:\(message.id)"
            case .task(let task):
                return "task:\(task.id)"
            }
        }
    }

    // MARK: - Connection

    @Published var isConnected: Bool = false
    @Published var isReachable: Bool = false
    @Published var serverHost: String = ""
    @Published var apiKey: String = ""

    // MARK: - Agent Status

    @Published var agentStatus: AgentStatus?

    // MARK: - Messages

    @Published var timeline: [TimelineItem] = []

    // MARK: - UI State

    @Published var isConnecting: Bool = false
    @Published var connectionError: String?

    // MARK: - Services

    private var mockService: MockService?
    private var webSocketClient: WebSocketClient?
    private var restClient: WindowClient?
    private var healthCheckTimer: Timer?

    // MARK: - Connection

    func attemptAutoConnect() {
        guard CredentialStore.hasSavedCredentials,
              let host = CredentialStore.loadHost(),
              let key = CredentialStore.loadApiKey() else {
            return
        }
        
        connect(host: host, key: key, useMock: false)
    }

    func connect(host: String, key: String, useMock: Bool = false) {
        serverHost = host
        apiKey = key
        isConnecting = true
        connectionError = nil

        if useMock {
            let mock = MockService(appState: self)
            self.mockService = mock
            mock.connect()
        } else {
            let rest = WindowClient(host: host, apiKey: key)
            self.restClient = rest

            Task {
                // Fetch status
                if let status = await rest.fetchStatus() {
                    self.agentStatus = status
                    self.isReachable = true
                } else {
                    self.connectionError = "Could not reach agent at \(host)"
                    self.isConnecting = false
                    self.isReachable = false
                    return
                }

                // Fetch recent messages
                if let history = await rest.fetchMessages(limit: 20) {
                    self.loadHistoryMessages(history)
                }

                // Connect WebSocket
                let ws = WebSocketClient(host: host, apiKey: key, appState: self)
                self.webSocketClient = ws
                ws.connect()
                
                // Save credentials on successful connection
                CredentialStore.saveHost(host)
                CredentialStore.saveApiKey(key)
                
                // Start health check polling
                startHealthCheck()
            }
        }
    }

    func disconnect() {
        stopHealthCheck()
        webSocketClient?.disconnect()
        mockService?.disconnect()
        webSocketClient = nil
        mockService = nil
        restClient = nil
        isConnected = false
        isConnecting = false
        isReachable = false
        agentStatus = nil
        timeline = []
        // Note: Does NOT clear saved credentials (use forgetAgent() for that)
    }
    
    func forgetAgent() {
        disconnect()
        CredentialStore.clear()
        serverHost = ""
        apiKey = ""
    }
    
    func handleWebSocketDisconnect() {
        isReachable = false
        // Optionally retry connection after a delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            if !isReachable, let ws = webSocketClient {
                ws.connect()
            }
        }
    }
    
    // MARK: - Health Check
    
    private func startHealthCheck() {
        stopHealthCheck()
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performHealthCheck()
            }
        }
    }
    
    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    private func performHealthCheck() async {
        guard let rest = restClient else { return }
        
        if let _ = await rest.fetchStatus() {
            isReachable = true
        } else {
            isReachable = false
        }
    }

    // MARK: - Send Message

    func sendMessage(_ content: String) {
        let clientId = "msg_\(UUID().uuidString.prefix(8))"
        let userMessage = Message(
            id: clientId,
            role: .user,
            content: content,
            timestamp: Date()
        )
        timeline.append(.message(userMessage))

        if let mock = mockService {
            mock.sendMessage(id: clientId, content: content)
        } else if let ws = webSocketClient {
            ws.send(id: clientId, content: content)
        }
    }

    // MARK: - Event Handlers (called by services)

    func handleConnected(agent: String, status: String, contextRemaining: Double, tokensUsed: Int = 0) {
        isConnected = true
        isConnecting = false
        agentStatus = AgentStatus(
            agent: agent,
            status: AgentStatus.AgentState(rawValue: status) ?? .idle,
            contextRemaining: contextRemaining,
            tokensUsed: tokensUsed
        )
    }

    func handleMessageStream(replyTo: String, delta: String) {
        // Find or create the agent's streaming message
        if let index = timeline.firstIndex(where: { item in
            if case .message(let message) = item {
                return message.id == "reply_\(replyTo)"
            }
            return false
        }) {
            guard case .message(var message) = timeline[index] else { return }
            message.content += delta
            timeline[index] = .message(message)
        } else {
            var msg = Message(
                id: "reply_\(replyTo)",
                role: .agent,
                content: delta,
                timestamp: Date()
            )
            msg.isStreaming = true
            timeline.append(.message(msg))
        }
    }

    func handleMessageComplete(replyTo: String, id: String, content: String, timestamp: Date) {
        // Replace the streaming message with the final one
        if let index = timeline.firstIndex(where: { item in
            if case .message(let message) = item {
                return message.id == "reply_\(replyTo)"
            }
            return false
        }) {
            timeline[index] = .message(Message(
                id: id,
                role: .agent,
                content: content,
                timestamp: timestamp
            ))
        } else {
            timeline.append(.message(Message(
                id: id,
                role: .agent,
                content: content,
                timestamp: timestamp
            )))
        }
    }

    func handleTaskCreated(taskId: String, title: String, progress: Double, steps: [TaskStep], shouldDisplay: Bool = true) {
        guard shouldDisplay else { return }
        let task = AgentTask(
            id: taskId,
            title: title,
            status: .inProgress,
            progress: progress,
            steps: steps
        )
        timeline.append(.task(task))
    }

    func handleTaskUpdated(taskId: String, progress: Double, steps: [TaskStep]) {
        guard let index = timeline.firstIndex(where: { item in
            if case .task(let task) = item {
                return task.id == taskId
            }
            return false
        }) else {
            return
        }

        guard case .task(var task) = timeline[index] else { return }
        task.progress = progress
        task.steps = steps
        timeline[index] = .task(task)
    }

    func handleTaskCompleted(taskId: String, progress: Double, result: String) {
        guard let index = timeline.firstIndex(where: { item in
            if case .task(let task) = item {
                return task.id == taskId
            }
            return false
        }) else {
            return
        }

        guard case .task(var task) = timeline[index] else { return }
        task.progress = progress
        task.status = .completed
        if task.title.hasPrefix("Processing:") {
            task.title = task.title.replacingOccurrences(of: "Processing:", with: "Completed:")
        }
        task.result = result
        for i in task.steps.indices {
            task.steps[i].status = .completed
        }
        timeline[index] = .task(task)
    }

    func handleStatusUpdate(status: String, contextRemaining: Double, tokensUsed: Int = 0) {
        agentStatus?.status = AgentStatus.AgentState(rawValue: status) ?? .idle
        agentStatus?.contextRemaining = contextRemaining
        if tokensUsed > 0 {
            agentStatus?.tokensUsed = tokensUsed
        }
    }

    func loadHistoryMessages(_ messages: [Message]) {
        timeline = messages.map { .message($0) }
    }
}
