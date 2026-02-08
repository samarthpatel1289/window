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
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            settingsView
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

    private var settingsView: some View {
        NavigationStack {
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
    }

    private func formatTokens(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
