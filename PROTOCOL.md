# Window Protocol v1

The Window Protocol defines how the Window iOS app communicates with any personal AI agent.

## Overview

- **REST** (2 endpoints): For catching up on state when the app opens or reconnects
- **WebSocket** (1 client event, 7 server events): For all real-time communication
- **Auth**: API key via `Authorization: Bearer <key>` header (query param for WebSocket)

## Authentication

```
REST:      Authorization: Bearer <api-key>
WebSocket: ws://host/ws?token=<api-key>
```

Status: Simple API key for v1. Proper auth deferred to future version.

---

## REST Endpoints

### GET /status

Agent health check. Called on app open.

**Request:**
```
GET /status
Authorization: Bearer <api-key>
```

**Response:**
```json
{
  "agent": "openclaw",
  "status": "idle",
  "context_remaining": 0.72,
  "version": "1.0.0"
}
```

| Field | Type | Description |
|-------|------|-------------|
| agent | string | Agent name/identifier |
| status | string | `"idle"` or `"busy"` |
| context_remaining | float | 0.0 to 1.0 - how much context window is left |
| version | string | Agent/protocol version |

---

### GET /messages

Fetch message history. Called on app open and for scroll-back pagination.

**Request:**
```
GET /messages?limit=20&before=2026-02-07T10:30:00Z
Authorization: Bearer <api-key>
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| limit | int | No | Number of messages to return (default: 20) |
| before | ISO 8601 | No | Return messages before this timestamp (for pagination) |

**Response:**
```json
{
  "messages": [
    {
      "id": "msg_server_042",
      "role": "user",
      "content": "Find me flights to Tokyo",
      "timestamp": "2026-02-07T10:30:00Z"
    },
    {
      "id": "msg_server_043",
      "role": "agent",
      "content": "I found 3 flights to Tokyo. The cheapest is...",
      "timestamp": "2026-02-07T10:30:05Z"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| id | string | Server-assigned message ID |
| role | string | `"user"` or `"agent"` |
| content | string | Message text |
| timestamp | ISO 8601 | When the message was sent/completed |

---

## WebSocket

Connect to: `ws://host/ws?token=<api-key>`

All messages are JSON. Every message has a `type` field.

---

### Client -> Server (1 event)

#### message.send

Send a message to the agent.

```json
{
  "type": "message.send",
  "id": "msg_client_001",
  "content": "Find me flights to Tokyo next week"
}
```

| Field | Type | Description |
|-------|------|-------------|
| type | string | Always `"message.send"` |
| id | string | Client-generated ID to match responses |
| content | string | The user's message text |

---

### Server -> Client (7 events)

#### connected

Sent once immediately after WebSocket connection is established.

```json
{
  "type": "connected",
  "agent": "openclaw",
  "status": "idle",
  "context_remaining": 0.72
}
```

---

#### message.stream

Partial response chunk. Client appends `delta` to the in-progress message. The server sends chunks at whatever granularity it chooses (token, word, sentence, paragraph).

```json
{
  "type": "message.stream",
  "reply_to": "msg_client_001",
  "delta": "I found 3 flights to Tokyo"
}
```

| Field | Type | Description |
|-------|------|-------------|
| reply_to | string | The client's `message.send` id |
| delta | string | New text to append |

---

#### message.complete

Response finished. Contains the full final message. Client can replace streamed chunks with this.

```json
{
  "type": "message.complete",
  "reply_to": "msg_client_001",
  "id": "msg_server_042",
  "content": "I found 3 flights to Tokyo. The cheapest is JAL at $450 direct.",
  "timestamp": "2026-02-07T10:30:05Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| reply_to | string | The client's `message.send` id |
| id | string | Server-assigned message ID (used in history) |
| content | string | Full final message text |
| timestamp | ISO 8601 | When the response completed |

---

#### task.created

Agent started a new multi-step task.

```json
{
  "type": "task.created",
  "task_id": "task_001",
  "title": "Search flight APIs",
  "visibility": "auto",
  "show_progress": true,
  "status": "in_progress",
  "progress": 0.0,
  "steps": [
    { "name": "Query Skyscanner", "status": "pending" },
    { "name": "Query Google Flights", "status": "pending" },
    { "name": "Compare prices", "status": "pending" }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| task_id | string | Unique task identifier |
| title | string | Human-readable task name |
| visibility | string | Optional: `"show"`, `"hide"`, or `"auto"` |
| show_progress | bool | Optional explicit override for whether UI should show the task card |
| status | string | `"in_progress"` |
| progress | float | 0.0 to 1.0 |
| steps | array | List of step objects |

Step object:

| Field | Type | Description |
|-------|------|-------------|
| name | string | Step description |
| status | string | `"pending"`, `"in_progress"`, `"completed"`, `"failed"` |

---

#### task.updated

Task progress changed.

```json
{
  "type": "task.updated",
  "task_id": "task_001",
  "progress": 0.33,
  "steps": [
    { "name": "Query Skyscanner", "status": "completed" },
    { "name": "Query Google Flights", "status": "in_progress" },
    { "name": "Compare prices", "status": "pending" }
  ]
}
```

---

#### task.completed

Task finished.

```json
{
  "type": "task.completed",
  "task_id": "task_001",
  "progress": 1.0,
  "result": "Found 3 flights. Best: JAL $450 direct."
}
```

| Field | Type | Description |
|-------|------|-------------|
| task_id | string | Task identifier |
| progress | float | Always 1.0 |
| result | string | Summary of what the task produced |

---

#### status.update

Agent state changed (pushed whenever context usage changes or agent goes idle/busy).

```json
{
  "type": "status.update",
  "status": "busy",
  "context_remaining": 0.58
}
```

---

## Complete Event Reference

| Direction | Event Type | Purpose |
|-----------|-----------|---------|
| Client -> Server | `message.send` | Send a message (the ONLY client event) |
| Server -> Client | `connected` | Handshake on connect |
| Server -> Client | `message.stream` | Streaming response chunks |
| Server -> Client | `message.complete` | Final complete response |
| Server -> Client | `task.created` | New task with steps |
| Server -> Client | `task.updated` | Progress + step status changes |
| Server -> Client | `task.completed` | Task done with result |
| Server -> Client | `status.update` | Context remaining, agent busy/idle |

## App Lifecycle Flow

1. App opens -> `GET /status` (is agent alive?)
2. `GET /messages?limit=20` (load recent chat history)
3. Connect WebSocket at `ws://host/ws?token=<key>`
4. Receive `connected` event
5. All further communication happens over WebSocket
6. If WebSocket disconnects -> reconnect -> repeat steps 1-4 to catch up
