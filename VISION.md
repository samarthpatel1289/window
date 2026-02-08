# Window — Vision & Future Features

**Window** is an open-source, decentralized iOS app for communicating with a personal AI agent. It replaces centralized chat interfaces (like Telegram) with a native iOS experience that shows real-time task progress and AI work visibility.

## Core Philosophy

- **Decentralized** — Connect to any IP where your agent lives. No central server, no vendor lock-in.
- **Transparent** — See exactly what the agent is doing (task cards with live step progress), not just the final answer.
- **Native** — SwiftUI, zero external dependencies (except tried-and-rejected MarkdownUI). Best iOS UX.
- **AI-Driven UX** — The agent decides when to show task cards, what the step names are, and how to present information. The UI adapts to the agent's choices.

## Current State (Feb 2026)

### Implemented
- ✅ Window Protocol v1 (REST + WebSocket)
- ✅ Custom markdown renderer (headings, lists, code blocks, inline formatting)
- ✅ Unified timeline (messages + task cards interleaved chronologically)
- ✅ AI-controlled task visibility (`window_task` tool — agent decides whether to show cards)
- ✅ Credential persistence (Keychain for API key, UserDefaults for host)
- ✅ Auto-reconnect on app launch
- ✅ Health check polling (green/red dot reflects server reachability)
- ✅ Disconnect (temporary) vs Forget Agent (wipes credentials)
- ✅ Demo mode (MockService for trying the app without a server)

### In Progress
- 🔄 Streaming responses (token-by-token text display)
  - **Problem:** LLM doesn't know if it will use tools until mid-generation. Streaming text that later gets replaced by tool output is bad UX.
  - **Solution under consideration:** Buffer streaming chunks, only emit to client once confirmed as text-only response, then rapid-replay for typing animation.

### Roadmap

#### High Priority
- **Streaming protocol** — Real-time token display for final responses (deferred due to tool call detection complexity)
- **Web search / weather tools** — Configure Brave API key and OpenWeather API key for nanobot
- **Exec tool safety** — Currently blocks certain shell commands. Configure allow/deny lists or remove restrictions.
- **Context remaining accuracy** — Currently hardcoded to 72%. Calculate real token usage and display accurate remaining context.
- **Auto-reconnect on WebSocket drop** — Currently retries once after 3s. Could be smarter (exponential backoff, connection state UI).

#### Medium Priority
- **Table support in markdown renderer** — Custom renderer doesn't support tables. Could add minimal table layout or revisit MarkdownUI with custom styling.
- **Message history pagination** — Currently loads last 20 messages on connect. Add "load more" for older conversations.
- **Multi-device sync** — Session state is server-side (nanobot JSONL files). Could add explicit sync/refresh.
- **Push notifications** — For background task completion or agent-initiated messages.
- **Voice input** — iOS speech-to-text for hands-free messaging.

#### Low Priority
- **iPad split view** — Optimize layout for larger screens.
- **Dark mode customization** — Currently uses system dark mode. Could add custom themes.
- **Export conversations** — Download full chat history as markdown/JSON.

---

## Future Feature: Self-Destruct / Full Agent Wipe

**Goal:** A "nuclear option" button in Settings that completely wipes the AI agent and all its data from the server.

### Use Case
The user wants to:
- Delete all conversation history
- Clear all memory files
- Revoke API access
- Optionally shut down the agent process
- Start completely fresh (or switch to a different agent)

### Proposed UX

**Settings → Danger Zone:**

```
Section(header: "Danger Zone") {
    Button("Wipe Agent Data", role: .destructive) {
        // Show confirmation alert
    }
}
```

**Confirmation Alert:**
- Title: "Wipe All Agent Data?"
- Message: "This will delete all conversations, memory, and revoke API access. This cannot be undone."
- Actions: [Cancel] [Wipe Everything (destructive)]

### Implementation Plan (Future)

#### 1. Server-Side API (nanobot)

Add a new endpoint to the Window Protocol:

**POST `/wipe`** (authenticated with API key)

```json
Request: { "confirm": true }

Response: { 
  "deleted": {
    "sessions": 15,
    "memory_files": 8,
    "workspace_files": 42
  },
  "api_key_revoked": true
}
```

Server-side operations (executed by nanobot):
```bash
# Delete all sessions
rm -rf ~/.nanobot/sessions/*

# Clear memory
rm -rf ~/.nanobot/workspace/memory/*

# Clear daily notes
rm -rf ~/.nanobot/workspace/daily/*

# Clear cron jobs
rm -rf ~/.nanobot/cron/*

# Revoke the API key (remove from config)
# This requires modifying config.json to remove or invalidate the window.api_key

# Optional: Shutdown the gateway process
# (Requires careful implementation to avoid breaking other channels)
```

#### 2. iOS App Changes

**New method in `AppState.swift`:**

```swift
func wipeAgent() async throws {
    guard let rest = restClient else { return }
    
    // Call wipe endpoint
    let success = await rest.wipeAgent()
    
    if success {
        // Local cleanup
        forgetAgent() // Clears Keychain + UserDefaults
        // Show success alert
    } else {
        // Show error alert
    }
}
```

**New method in `WindowClient.swift`:**

```swift
func wipeAgent() async -> Bool {
    guard let url = URL(string: "\(baseURL)/wipe") else { return false }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["confirm": true]
    request.httpBody = try? JSONEncoder().encode(body)
    
    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        return true
    } catch {
        return false
    }
}
```

**Add to Settings in `ContentView.swift`:**

```swift
Section(header: Text("Danger Zone")) {
    Button("Wipe Agent Data", role: .destructive) {
        showWipeConfirmation = true
    }
}
.alert("Wipe All Agent Data?", isPresented: $showWipeConfirmation) {
    Button("Cancel", role: .cancel) { }
    Button("Wipe Everything", role: .destructive) {
        Task {
            try? await appState.wipeAgent()
        }
    }
} message: {
    Text("This will delete all conversations, memory, and revoke API access. This cannot be undone.")
}
```

#### 3. Security Considerations

- **Require re-authentication before wipe** — Ask for the API key again (or implement a PIN/biometric confirmation)
- **Server-side rate limiting** — Prevent rapid wipe requests (could be abuse/attack)
- **Backup prompt** — Offer to export conversation history before wiping
- **Soft delete option** — Archive instead of hard delete (allow restore within 30 days)

#### 4. Alternative: Partial Wipe Options

Instead of one nuclear button, offer granular choices:

```
Wipe Options:
  [ ] Delete all conversations (sessions)
  [ ] Clear all memory files
  [ ] Clear workspace files
  [ ] Revoke API key
  [ ] Shutdown agent process

[Wipe Selected Items]
```

---

## Protocol Extensions Under Consideration

### 1. Streaming Enhancement
- Add `message.discard` event to allow rolling back partial streamed text when tool calls appear

### 2. File Attachments
- Extend `message.send` to include base64-encoded images/files
- Agent can process images (OCR, analysis, etc.)

### 3. Agent Capabilities Handshake
- On `connected` event, agent sends list of available tools/skills
- iOS app can show tool-specific UI (e.g., "Request Location" button when `location` tool is available)

### 4. Multi-Agent Support
- Connect to multiple agents simultaneously
- Switch between agents via a dropdown in the status bar
- Each agent has its own timeline, credentials, health status

---

## Design Decisions Archive

### Why No External Dependencies?
We tried `swift-markdown-ui` for rendering. It was excellent technically but made chat bubbles look like documentation pages instead of messages. The custom renderer (40 lines) gives us full control over styling and feels native to chat.

### Why Decentralized?
Centralized chat apps (ChatGPT, Claude.ai) lock you into their infrastructure. Window lets you connect to *your* agent running *anywhere* — your VPS, your homelab, your laptop. The agent is yours, the data is yours, the compute is yours.

### Why iOS-Only (for now)?
Focus. Building a great iOS app is hard enough. Android/web/desktop can come later. SwiftUI gives us the best iOS UX with minimal code.

### Why Not Just Use Telegram?
Telegram works but lacks:
- Real-time task progress visibility (no task cards)
- Native iOS feel (Telegram is cross-platform, feels generic)
- AI-driven UX (agent can't control how information is displayed)
- Custom rendering (markdown in Telegram is limited)

Window is purpose-built for AI agent communication with transparency and native UX as core values.

---

## Contributing

Window is open source (license TBD). Contributions welcome once the core is stable. Focus areas:
- Streaming implementation (solve the tool call detection problem)
- Android app (Jetpack Compose)
- Web client (SvelteKit or Next.js)
- Protocol v2 design (streaming enhancements, file attachments, multi-agent)

---

**Last Updated:** February 2026  
**Current Version:** Window Protocol v1 + nanobot WindowChannel integration  
**Status:** Beta (functional, actively used, not production-ready)
