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
                                .fill(appState.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(appState.isConnected ? "Connected" : "Disconnected")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Agent State")
                        Spacer()
                        Text(appState.agentStatus?.status.rawValue.capitalized ?? "-")
                            .foregroundStyle(.secondary)
                    }

                    if let ctx = appState.agentStatus?.contextRemaining {
                        HStack {
                            Text("Context Left")
                            Spacer()
                            Text("\(Int(ctx * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Disconnect", role: .destructive) {
                        appState.disconnect()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
