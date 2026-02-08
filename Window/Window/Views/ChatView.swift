import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.timeline) { item in
                            switch item {
                            case .message(let message):
                                ChatBubble(message: message)
                                    .id(item.id)
                            case .task(let task):
                                TaskRowView(task: task)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: appState.timeline.count) { _, _ in
                    if let lastId = appState.timeline.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Agent name + reachability dot
            HStack(spacing: 6) {
                Circle()
                    .fill(reachabilityColor)
                    .frame(width: 8, height: 8)

                Text(appState.agentStatus?.agent ?? "Agent")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let state = appState.agentStatus?.status {
                    Text(state == .busy ? "busy" : "idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Token usage
            if let status = appState.agentStatus {
                Text(formatTokens(status.tokensUsed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var reachabilityColor: Color {
        appState.isReachable ? .green : .red
    }

    private func formatTokens(_ count: Int) -> String {
        if count == 0 { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(formatted) tokens"
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message your agent...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendMessage(text)
    }
}
