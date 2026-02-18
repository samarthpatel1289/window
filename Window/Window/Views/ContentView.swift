import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isConnected {
                mainView
            } else {
                ConnectView()
            }
        }
    }

    private var mainView: some View {
        NavigationStack {
            ChatView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.isReachable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(appState.agentStatus?.agent ?? "Agent")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let state = appState.agentStatus?.status {
                                Text(state == .busy ? "busy" : "idle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let status = appState.agentStatus, status.tokensUsed > 0 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(formatTokens(status.tokensUsed))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            settingsView
                        } label: {
                            Image(systemName: "gear")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }

    private var settingsView: some View {
        List {
            Section("Connection") {
                HStack {
                    Text("Server")
                    Spacer()
                    Text(appState.serverHost)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Reachability")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isReachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(appState.isReachable ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Agent State")
                    Spacer()
                    Text(appState.agentStatus?.status.rawValue.capitalized ?? "-")
                        .foregroundStyle(.secondary)
                }

                if let status = appState.agentStatus, status.tokensUsed > 0 {
                    HStack {
                        Text("Tokens Used")
                        Spacer()
                        Text(formatTokens(status.tokensUsed))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Disconnect") {
                    appState.disconnect()
                }

                Button("Forget Agent", role: .destructive) {
                    appState.forgetAgent()
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func formatTokens(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
