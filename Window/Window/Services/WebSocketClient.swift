import Foundation

/// WebSocket client for the Window Protocol.
/// Handles real-time communication: message streaming, task updates, status.
class WebSocketClient {
    private let host: String
    private let apiKey: String
    private weak var appState: AppState?
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false

    init(host: String, apiKey: String, appState: AppState) {
        self.host = host
        self.apiKey = apiKey
        self.appState = appState
    }

    // MARK: - Connect

    func connect() {
        let cleanHost: String
        if host.hasPrefix("http://") {
            cleanHost = String(host.dropFirst(7))
        } else if host.hasPrefix("https://") {
            cleanHost = String(host.dropFirst(8))
        } else {
            cleanHost = host
        }

        let wsURL = "ws://\(cleanHost)/ws?token=\(apiKey)"

        guard let url = URL(string: wsURL) else {
            print("[WebSocketClient] Invalid URL: \(wsURL)")
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true

        receiveMessage()
    }

    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Send

    func send(id: String, content: String) {
        let event = SendMessageEvent(id: id, content: content)

        guard let data = try? JSONEncoder().encode(event),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("[WebSocketClient] Send error: \(error)")
            }
        }
    }

    // MARK: - Receive

    private func receiveMessage() {
        guard isConnected else { return }

        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handleEvent(data: data)
                    }
                case .data(let data):
                    self.handleEvent(data: data)
                @unknown default:
                    break
                }

                // Continue listening
                self.receiveMessage()

            case .failure(let error):
                print("[WebSocketClient] Receive error: \(error)")
                self.isConnected = false
                Task { @MainActor [weak self] in
                    self?.appState?.handleWebSocketDisconnect()
                }
            }
        }
    }

    // MARK: - Event Handling

    private func handleEvent(data: Data) {
        guard let event = ServerEventParser.parse(json: data) else {
            print("[WebSocketClient] Could not parse event")
            return
        }

        Task { @MainActor [weak self] in
            guard let appState = self?.appState else { return }

            switch event {
            case .connected(let e):
                appState.handleConnected(
                    agent: e.agent,
                    status: e.status,
                    contextRemaining: e.contextRemaining,
                    tokensUsed: e.tokensUsed ?? 0
                )

            case .messageStream(let e):
                appState.handleMessageStream(replyTo: e.replyTo, delta: e.delta)

            case .messageComplete(let e):
                let formatter = ISO8601DateFormatter()
                let date = formatter.date(from: e.timestamp) ?? Date()
                appState.handleMessageComplete(
                    replyTo: e.replyTo,
                    id: e.id,
                    content: e.content,
                    timestamp: date
                )

            case .taskCreated(let e):
                let steps = e.steps.map { stepEvent in
                    TaskStep(
                        name: stepEvent.name,
                        status: TaskStep.StepStatus(rawValue: stepEvent.status) ?? .pending
                    )
                }

                let shouldDisplayTask: Bool = {
                    if let showProgress = e.showProgress {
                        return showProgress
                    }

                    guard let visibility = e.visibility?.lowercased() else {
                        return true
                    }

                    switch visibility {
                    case "hide":
                        return false
                    case "show":
                        return true
                    case "auto":
                        return e.steps.count > 1
                    default:
                        return true
                    }
                }()

                appState.handleTaskCreated(
                    taskId: e.taskId,
                    title: e.title,
                    progress: e.progress,
                    steps: steps,
                    shouldDisplay: shouldDisplayTask
                )

            case .taskUpdated(let e):
                let steps = e.steps.map { stepEvent in
                    TaskStep(
                        name: stepEvent.name,
                        status: TaskStep.StepStatus(rawValue: stepEvent.status) ?? .pending
                    )
                }
                appState.handleTaskUpdated(
                    taskId: e.taskId,
                    progress: e.progress,
                    steps: steps
                )

            case .taskCompleted(let e):
                appState.handleTaskCompleted(
                    taskId: e.taskId,
                    progress: e.progress,
                    result: e.result
                )

            case .statusUpdate(let e):
                appState.handleStatusUpdate(
                    status: e.status,
                    contextRemaining: e.contextRemaining,
                    tokensUsed: e.tokensUsed ?? 0
                )
            }
        }
    }
}
