import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
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

            // Input bar
            inputBar
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("iMessage", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())

            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
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
