# Window

Open-source iOS client for personal AI agents.

Window gives you a chat-first interface with live visibility into what your agent is doing, without relying on Telegram or centralized platforms.

## Why Window

- Chat should be immediate: open app -> start talking
- You should see agent progress, not only final answers
- Your agent should run anywhere you want (local machine, VPS, home server)
- The interface and protocol should be open source and reusable

## Current Features

- Native SwiftUI iOS app
- Connect screen for host + API key
- Unified timeline chat UI (messages + inline task/progress cards)
- Streaming responses in chat
- Context usage indicator in status bar
- Demo mode with mock agent events (no backend required)

## Protocol

Protocol spec is documented in `PROTOCOL.md`.

High-level design:
- REST for catch-up state (`/status`, `/messages`)
- WebSocket for real-time events (message stream, task updates, status updates)

## Run Locally

Requirements:
- Xcode 16+
- iOS Simulator runtime installed

Steps:

```bash
git clone https://github.com/samarthpatel1289/window.git
cd window
open Window/Window.xcodeproj
```

In Xcode:
- Select the `Window` scheme
- Pick an iPhone simulator
- Run (`Cmd+R`)
- Tap `Try Demo Mode` on the connect screen

## Project Structure

- `Window/Window/Views` - UI screens and components
- `Window/Window/State` - app state and event handling
- `Window/Window/Services` - REST/WebSocket clients + mock service
- `Window/Window/Models` - protocol and app models
- `PROTOCOL.md` - API/event specification

## Roadmap

- Harden auth (beyond simple API key)
- Reference server implementation
- Better markdown/table rendering in chat while preserving compact bubble UX
- Multi-agent support

## License

TBD
