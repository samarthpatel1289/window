# Window

> A window into what your AI agent is doing in real-time.

## The Problem

Telegram (and similar messaging apps) work fine for simple chatbot Q&A, but they fall short when you're running a **personal AI agent** (like OpenClaw, Nanobot, etc.) that performs multi-step tasks. With Telegram:

- You only see the final result, not the process
- No visibility into what your AI is actually doing right now
- No progress tracking for multi-step tasks
- You're locked into Telegram's ecosystem
- No clean API for developers to build on top of
- Your agent lives on your own server, but the interface is centralized

## What Window Is

Window is an **open-source, decentralized iOS app** for communicating with your personal AI agent. It is not a chatbot platform - it is a **client** that connects to wherever your AI agent lives.

### Core Pillars

#### 1. Chat Interface
- Opens directly to chat on launch - no friction
- Full message history with scroll-back
- Clean, native iOS experience (SwiftUI)
- Purpose-built for personal AI conversations

#### 2. Agent Transparency (The Differentiator)
- **Real-time task visibility**: See what your AI agent is working on right now
- **Todo list view**: Multi-step tasks displayed as a checklist with progress
- **Progress bars**: Visual progress for each step in a multi-step workflow
- **Not just results - the process**: You watch your agent think, plan, and execute

#### 3. Simple, Robust API
- Open-source API specification anyone can implement
- REST endpoints for catch-up state (messages, status)
- WebSocket for real-time streaming responses and live progress updates
- Standard protocol so any AI backend can plug in

#### 4. Decentralized by Design
- Connect to **any IP address** where your AI agent runs
- No central server, no middleman
- Your agent lives on your hardware (home server, VPS, anywhere)
- You just point Window at your agent's address and start talking

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | iOS only (for now) | Focus and polish over breadth |
| Framework | SwiftUI | Native iOS feel, best performance, Apple ecosystem |
| API Protocol | REST + WebSocket hybrid | REST for catch-up state, WebSocket for everything real-time |
| Architecture | Decentralized | App connects directly to agent at any IP/domain |
| Dependencies | Zero external | Pure SwiftUI + Foundation |

## Key Screens

1. **Server Connect** - Enter your agent's IP/domain + API key, connect
2. **Chat View** - Main conversation interface, send messages, see responses stream in
3. **Agent Activity** - Todo list / progress view showing what the agent is doing in real-time
4. **History** - Browse past conversations (via scrollback in chat)

## What This Is NOT

- Not a chatbot platform (no hosted AI)
- Not a SaaS product (no subscription, no central server)
- Not Telegram/WhatsApp/Signal (not a general messenger)
- Not tied to any specific AI model or framework

## Open Source Philosophy

Window is open source because:
- Personal AI should not be locked behind proprietary interfaces
- The API spec should be a community standard anyone can implement
- Transparency in how you talk to your AI matters
- Anyone should be able to fork, modify, and self-host

## Authorization (Deferred)

Current approach: Simple API key (`Bearer <token>`) for v1.

Open questions to solve later:
1. Single user vs. multi-user
2. Key generation & exchange (copy-paste? QR code? pairing flow?)
3. Key rotation / revocation
4. Transport security (TLS, self-signed certs for home servers)
5. Device identity (iPhone vs iPad connecting to same agent)

## Future Possibilities (Not Now)

- Android version
- Desktop version (macOS native)
- Multiple agent connections (switch between agents)
- Agent marketplace (discover community agents)
- End-to-end encryption for agent communication
- Plugin system for custom agent activity views

---

*Project started: February 2026*
*Author: Sam*
