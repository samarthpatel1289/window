import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var appState: AppState
    @State private var host: String = ""
    @State private var apiKey: String = ""
    @State private var useMock: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                        .font(.system(size: 56))
                        .foregroundStyle(.primary)

                    Text("Window")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("A window into your AI agent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Connection Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Agent Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("192.168.1.100:8080", text: $host)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)

                // Error
                if let error = appState.connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Connect Button
                VStack(spacing: 12) {
                    Button {
                        appState.connect(host: host, key: apiKey, useMock: false)
                    } label: {
                        if appState.isConnecting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("Connect")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(host.isEmpty || apiKey.isEmpty || appState.isConnecting)
                    .padding(.horizontal)

                    // Demo mode button
                    Button {
                        appState.connect(host: "mock", key: "mock", useMock: true)
                    } label: {
                        Text("Try Demo Mode")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(appState.isConnecting)
                }

                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                // Pre-fill from saved credentials if available
                if let savedHost = CredentialStore.loadHost() {
                    host = savedHost
                }
                if let savedKey = CredentialStore.loadApiKey() {
                    apiKey = savedKey
                }
            }
        }
    }
}
