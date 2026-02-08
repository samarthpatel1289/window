import Foundation

/// Simulates a Window Protocol server with fake data.
/// Used for UI development and testing without a real agent.
@MainActor
class MockService {
    private weak var appState: AppState?
    private var streamTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    func connect() {
        // Simulate connection delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            appState?.handleConnected(
                agent: "mock-agent",
                status: "idle",
                contextRemaining: 0.85,
                tokensUsed: 3200
            )

            // Load some fake history
            loadMockHistory()
        }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
    }

    func sendMessage(id: String, content: String) {
        streamTask = Task {
            // Simulate agent thinking
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Update status to busy
            appState?.handleStatusUpdate(status: "busy", contextRemaining: 0.78, tokensUsed: 4100)

            // AI decides whether progress should be visible.
            let shouldShowProgress = shouldShowProgress(for: content)
            let taskId = "task_\(UUID().uuidString.prefix(6))"

            if shouldShowProgress {
                appState?.handleTaskCreated(
                    taskId: taskId,
                    title: "Processing: \(String(content.prefix(30)))",
                    progress: 0.0,
                    steps: [
                        TaskStep(name: "Understanding request", status: .inProgress),
                        TaskStep(name: "Generating response", status: .pending),
                        TaskStep(name: "Finalizing", status: .pending)
                    ]
                )
            }

            // Step 1 complete
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            if shouldShowProgress {
                appState?.handleTaskUpdated(
                    taskId: taskId,
                    progress: 0.33,
                    steps: [
                        TaskStep(name: "Understanding request", status: .completed),
                        TaskStep(name: "Generating response", status: .inProgress),
                        TaskStep(name: "Finalizing", status: .pending)
                    ]
                )
            }

            // Stream the response
            let response = generateMockResponse(for: content)
            let words = response.split(separator: " ")

            for (i, word) in words.enumerated() {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms per word
                let delta = (i == 0 ? "" : " ") + String(word)
                appState?.handleMessageStream(replyTo: id, delta: delta)
            }

            // Step 2 complete
            if Task.isCancelled { return }
            if shouldShowProgress {
                appState?.handleTaskUpdated(
                    taskId: taskId,
                    progress: 0.66,
                    steps: [
                        TaskStep(name: "Understanding request", status: .completed),
                        TaskStep(name: "Generating response", status: .completed),
                        TaskStep(name: "Finalizing", status: .inProgress)
                    ]
                )
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            // Complete the message
            let timestamp = Date()
            let msgId = "msg_\(UUID().uuidString.prefix(8))"
            appState?.handleMessageComplete(
                replyTo: id,
                id: msgId,
                content: response,
                timestamp: timestamp
            )

            // Complete the task
            if shouldShowProgress {
                appState?.handleTaskCompleted(
                    taskId: taskId,
                    progress: 1.0,
                    result: "Response delivered"
                )
            }

            // Back to idle
            appState?.handleStatusUpdate(status: "idle", contextRemaining: 0.72, tokensUsed: 5600)
        }
    }

    private func shouldShowProgress(for content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 24 { return true }

        let complexKeywords = [
            "analyze", "plan", "build", "deploy", "search", "debug", "investigate", "compare", "write"
        ]
        let lowercase = trimmed.lowercased()
        return complexKeywords.contains { lowercase.contains($0) }
    }

    // MARK: - Mock Data

    private func loadMockHistory() {
        let now = Date()
        let messages = [
            Message(
                id: "msg_hist_001",
                role: .user,
                content: "Hey, can you check the server status?",
                timestamp: now.addingTimeInterval(-3600)
            ),
            Message(
                id: "msg_hist_002",
                role: .agent,
                content: "All systems are running normally. CPU usage is at 23%, memory at 4.2GB/16GB. No alerts in the last 24 hours.",
                timestamp: now.addingTimeInterval(-3550)
            ),
            Message(
                id: "msg_hist_003",
                role: .user,
                content: "Great, thanks!",
                timestamp: now.addingTimeInterval(-3500)
            ),
        ]
        appState?.loadHistoryMessages(messages)
    }

    private func generateMockResponse(for input: String) -> String {
        let normalized = input.lowercased()
        if normalized.contains("markdown") || normalized.contains("md demo") {
            if normalized.contains("code") {
                return markdownCodeDemo
            }
            return markdownFullDemo
        }

        let responses = [
            "I've looked into that for you. Here's what I found: the system is running smoothly with no issues detected. I'll keep monitoring and let you know if anything changes.",
            "Done! I've processed your request. Everything looks good on my end. The task completed successfully with no errors.",
            "Interesting question. Based on my analysis, I'd recommend proceeding with the current approach. The metrics look favorable and the risk is minimal.",
            "I've completed the task you requested. Here's a summary: all steps executed successfully, data was processed correctly, and the results have been saved.",
            "Working on it now. After analyzing the situation, I can confirm that everything is in order. No action needed from your side at this point."
        ]
        return responses[abs(input.hashValue) % responses.count]
    }

    private var markdownFullDemo: String {
        """
        # Markdown Demo Playground

        This tests **bold**, *italic*, ***bold italic***, ~~strikethrough~~, and `inline code`.

        > Blockquote: This is a quoted line.
        > Second quoted line with a [link](https://openai.com).

        ## Lists

        - Bullet one
        - Bullet two
          - Nested bullet A
          - Nested bullet B
        - Bullet three with emoji 🔥✅🙂

        1. Ordered item one
        2. Ordered item two
        3. Ordered item three

        ## Task List

        - [x] Completed task
        - [ ] Pending task

        ## Horizontal Rule

        ---

        ## Code Block

        ```swift
        struct User {
            let id: Int
            let name: String
        }

        let user = User(id: 1, name: "Sam")
        print("Hello, \\(user.name)")
        ```

        ## Inline URL

        https://example.com/docs

        ## Final Line

        If this renders well, markdown support is working end-to-end.
        """
    }

    private var markdownCodeDemo: String {
        """
        ## Code Formatting Demo

        Inline examples: `let x = 42`, `npm run build`, `POST /api/v1/message`

        ```json
        {
          "type": "message.send",
          "id": "msg_123",
          "content": "hello"
        }
        ```

        ```bash
        curl -X GET http://127.0.0.1:8080/status
        ```
        """
    }
}
