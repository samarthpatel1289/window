#!/bin/bash
# ============================================================================
# Window Protocol Bridge for OpenClaw — Installer
#
# Connects the Window iOS app to an OpenClaw agent via the Window Protocol.
# Run on your VPS where OpenClaw is already running:
#
#   curl -sL https://raw.githubusercontent.com/samarthpatel1289/window/main/bridge/install.sh | bash
#
# What this does:
#   1. Creates /opt/window-bridge/ with bridge server files
#   2. Installs Node.js dependency (ws)
#   3. Sets up a systemd service for auto-start
#   4. Prints the URL + API key to enter in the Window iOS app
#
# Requirements:
#   - Linux VPS with OpenClaw gateway running
#   - Node.js >= 18
#   - Root access (for systemd + /opt/)
# ============================================================================

set -e

INSTALL_DIR="/opt/window-bridge"
SERVICE_NAME="window-bridge"
BRIDGE_VERSION="0.1.0"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $1"; }
fail()  { echo -e "${RED}[error]${NC} $1"; exit 1; }

# ============================================================================
# Prerequisites
# ============================================================================

echo ""
echo -e "${BOLD}Window Protocol Bridge for OpenClaw${NC}"
echo -e "${BOLD}====================================${NC}"
echo ""

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  fail "This script must be run as root. Try: sudo bash install.sh"
fi

# Check Node.js
if ! command -v node &>/dev/null; then
  fail "Node.js is not installed. Install Node.js >= 18 first: https://nodejs.org"
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  fail "Node.js >= 18 required (found v$(node -v)). Please upgrade."
fi
ok "Node.js $(node -v)"

# Check npm
if ! command -v npm &>/dev/null; then
  fail "npm is not installed."
fi
ok "npm $(npm -v)"

# ============================================================================
# Auto-detect OpenClaw gateway config
# ============================================================================

GATEWAY_URL=""
GATEWAY_TOKEN=""
GATEWAY_PORT="18789"

# Try to read from OpenClaw config
OPENCLAW_CONFIG=""
for cfg_path in "$HOME/.openclaw/openclaw.json" "/root/.openclaw/openclaw.json"; do
  if [ -f "$cfg_path" ]; then
    OPENCLAW_CONFIG="$cfg_path"
    break
  fi
done

if [ -n "$OPENCLAW_CONFIG" ]; then
  info "Found OpenClaw config: $OPENCLAW_CONFIG"

  # Extract gateway token
  DETECTED_TOKEN=$(python3 -c "
import json, sys
try:
    d = json.load(open('$OPENCLAW_CONFIG'))
    print(d.get('gateway', {}).get('auth', {}).get('token', ''))
except: pass
" 2>/dev/null || true)

  # Extract gateway port
  DETECTED_PORT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$OPENCLAW_CONFIG'))
    print(d.get('gateway', {}).get('port', ''))
except: pass
" 2>/dev/null || true)

  if [ -n "$DETECTED_TOKEN" ]; then
    GATEWAY_TOKEN="$DETECTED_TOKEN"
    ok "Detected gateway token: ${GATEWAY_TOKEN:0:12}..."
  fi

  if [ -n "$DETECTED_PORT" ]; then
    GATEWAY_PORT="$DETECTED_PORT"
    ok "Detected gateway port: $GATEWAY_PORT"
  fi
fi

# Check if gateway is reachable
if command -v ss &>/dev/null; then
  if ss -tlnp | grep -q ":${GATEWAY_PORT}"; then
    ok "OpenClaw gateway is running on port $GATEWAY_PORT"
  else
    warn "No service detected on port $GATEWAY_PORT. Is OpenClaw gateway running?"
  fi
fi

# ============================================================================
# Interactive config
# ============================================================================

echo ""
echo -e "${BOLD}Configuration${NC}"
echo ""

# Gateway URL
DEFAULT_GW_URL="ws://127.0.0.1:${GATEWAY_PORT}"
read -rp "OpenClaw Gateway URL [$DEFAULT_GW_URL]: " INPUT_GW_URL
GATEWAY_URL="${INPUT_GW_URL:-$DEFAULT_GW_URL}"

# Gateway token
if [ -n "$GATEWAY_TOKEN" ]; then
  read -rp "Gateway auth token [detected: ${GATEWAY_TOKEN:0:12}...]: " INPUT_TOKEN
  GATEWAY_TOKEN="${INPUT_TOKEN:-$GATEWAY_TOKEN}"
else
  read -rp "Gateway auth token (from ~/.openclaw/openclaw.json -> gateway.auth.token): " GATEWAY_TOKEN
  if [ -z "$GATEWAY_TOKEN" ]; then
    fail "Gateway token is required. Find it in your OpenClaw config: gateway.auth.token"
  fi
fi

# Bridge port
DEFAULT_PORT="8081"
read -rp "Bridge port (the port Window iOS app connects to) [$DEFAULT_PORT]: " INPUT_PORT
BRIDGE_PORT="${INPUT_PORT:-$DEFAULT_PORT}"

# Agent name
DEFAULT_NAME="openclaw"
read -rp "Agent name (shown in the iOS app) [$DEFAULT_NAME]: " INPUT_NAME
AGENT_NAME="${INPUT_NAME:-$DEFAULT_NAME}"

# Session key
DEFAULT_SESSION="agent:main:window:dm:ios"
read -rp "Session key [$DEFAULT_SESSION]: " INPUT_SESSION
SESSION_KEY="${INPUT_SESSION:-$DEFAULT_SESSION}"

# Generate API key
API_KEY=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

echo ""
info "Configuration summary:"
echo "  Gateway URL:  $GATEWAY_URL"
echo "  Gateway token: ${GATEWAY_TOKEN:0:12}..."
echo "  Bridge port:  $BRIDGE_PORT"
echo "  Agent name:   $AGENT_NAME"
echo "  Session key:  $SESSION_KEY"
echo "  API key:      $API_KEY"
echo ""
read -rp "Proceed with installation? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn] ]]; then
  echo "Aborted."
  exit 0
fi

# ============================================================================
# Check for existing installation
# ============================================================================

if [ -d "$INSTALL_DIR" ]; then
  warn "Existing installation found at $INSTALL_DIR"
  read -rp "Overwrite? (existing config.json and device-identity.json will be preserved) [Y/n]: " OVERWRITE
  if [[ "$OVERWRITE" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
  fi
  # Stop existing service if running
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
fi

# ============================================================================
# Create install directory
# ============================================================================

mkdir -p "$INSTALL_DIR"
info "Installing to $INSTALL_DIR"

# ============================================================================
# Write package.json
# ============================================================================

cat > "$INSTALL_DIR/package.json" << 'PKGJSON'
{
  "name": "window-bridge",
  "version": "0.1.0",
  "description": "Window Protocol bridge for OpenClaw Gateway",
  "type": "module",
  "main": "server.js",
  "dependencies": {
    "ws": "^8.0.0"
  }
}
PKGJSON

# ============================================================================
# Write config.json
# ============================================================================

cat > "$INSTALL_DIR/config.json" << CONFIGJSON
{
  "gateway": {
    "url": "$GATEWAY_URL",
    "token": "$GATEWAY_TOKEN"
  },
  "window": {
    "host": "0.0.0.0",
    "port": $BRIDGE_PORT,
    "apiKey": "$API_KEY"
  },
  "agent": {
    "name": "$AGENT_NAME",
    "sessionKey": "$SESSION_KEY"
  }
}
CONFIGJSON
chmod 600 "$INSTALL_DIR/config.json"

# ============================================================================
# Write gateway.js — OpenClaw Gateway WebSocket client
# ============================================================================

cat > "$INSTALL_DIR/gateway.js" << 'GATEWAYJS'
/**
 * OpenClaw Gateway WebSocket client.
 * Handles ED25519 device auth, connect handshake, and RPC calls.
 */

import crypto from "node:crypto";
import fs from "node:fs";
import { WebSocket } from "ws";
import { EventEmitter } from "node:events";

const IDENTITY_FILE = new URL("./device-identity.json", import.meta.url).pathname;
const PROTOCOL_VERSION = 3;

export class GatewayClient extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.ws = null;
    this.connected = false;
    this.reqId = 0;
    this.pendingRequests = new Map();
    this.identity = this._loadOrCreateIdentity();
    this.connectNonce = null;
    this.reconnectTimer = null;
  }

  _loadOrCreateIdentity() {
    if (fs.existsSync(IDENTITY_FILE)) {
      return JSON.parse(fs.readFileSync(IDENTITY_FILE, "utf8"));
    }

    const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
    const pubPem = publicKey.export({ type: "spki", format: "pem" }).toString();
    const privPem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();

    const spki = publicKey.export({ type: "spki", format: "der" });
    const raw = spki.subarray(spki.length - 32);
    const deviceId = crypto.createHash("sha256").update(raw).digest("hex");
    const publicKeyBase64Url = this._base64url(raw);

    const identity = { deviceId, publicKeyPem: pubPem, privateKeyPem: privPem, publicKeyBase64Url };
    fs.writeFileSync(IDENTITY_FILE, JSON.stringify(identity, null, 2), { mode: 0o600 });
    console.log("[gateway] Created device identity:", deviceId.substring(0, 12) + "...");
    return identity;
  }

  _base64url(buf) {
    return buf.toString("base64").replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  }

  _signPayload(payload) {
    const key = crypto.createPrivateKey(this.identity.privateKeyPem);
    const sig = crypto.sign(null, Buffer.from(payload, "utf8"), key);
    return this._base64url(sig);
  }

  _buildDeviceAuthPayload(nonce, signedAtMs) {
    return [
      "v2",
      this.identity.deviceId,
      "gateway-client",
      "backend",
      "operator",
      "operator.admin",
      String(signedAtMs),
      this.config.gateway.token,
      nonce
    ].join("|");
  }

  connect() {
    if (this.ws) {
      try { this.ws.close(); } catch {}
    }

    console.log("[gateway] Connecting to", this.config.gateway.url);
    this.ws = new WebSocket(this.config.gateway.url);
    this.connected = false;

    this.ws.on("open", () => {
      console.log("[gateway] WebSocket open, waiting for challenge...");
    });

    this.ws.on("message", (data) => {
      try {
        this._handleMessage(JSON.parse(data.toString()));
      } catch (e) {
        console.error("[gateway] Parse error:", e.message);
      }
    });

    this.ws.on("close", () => {
      console.log("[gateway] Disconnected");
      this.connected = false;
      this.emit("disconnected");
      this._scheduleReconnect();
    });

    this.ws.on("error", (e) => {
      console.error("[gateway] Error:", e.message);
    });
  }

  _scheduleReconnect() {
    if (this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      console.log("[gateway] Reconnecting...");
      this.connect();
    }, 5000);
  }

  _handleMessage(msg) {
    // Log relevant events (skip tick/health noise)
    if (msg.event !== "tick" && msg.event !== "health" && msg.event !== "heartbeat") {
      const raw = JSON.stringify(msg);
      console.log("[gateway] <<", raw.length > 300 ? raw.substring(0, 300) + "..." : raw);
    }

    // Connect challenge
    if (msg.type === "event" && msg.event === "connect.challenge") {
      this._sendConnectRequest(msg.payload.nonce);
      return;
    }

    // RPC response
    if (msg.type === "res") {
      if (msg.id === "connect-init") {
        if (msg.ok) {
          this.connected = true;
          console.log("[gateway] Connected to OpenClaw Gateway");
          this.emit("connected");
        } else {
          console.error("[gateway] Connect failed:", msg.error?.message);
          this.ws.close();
        }
        return;
      }

      const pending = this.pendingRequests.get(msg.id);
      if (pending) {
        this.pendingRequests.delete(msg.id);
        if (msg.ok) pending.resolve(msg.payload);
        else pending.reject(new Error(msg.error?.message || "RPC failed"));
      }

      // Always emit so server.js can see chat.send responses
      this.emit("gateway-event", msg);
      return;
    }

    if (msg.type === "event") {
      this.emit("gateway-event", msg);
      return;
    }

    this.emit("gateway-event", msg);
  }

  _sendConnectRequest(nonce) {
    const signedAtMs = Date.now();
    const payload = this._buildDeviceAuthPayload(nonce, signedAtMs);
    const signature = this._signPayload(payload);

    this.ws.send(JSON.stringify({
      type: "req",
      id: "connect-init",
      method: "connect",
      params: {
        minProtocol: PROTOCOL_VERSION,
        maxProtocol: PROTOCOL_VERSION,
        client: {
          id: "gateway-client",
          platform: "linux",
          mode: "backend",
          version: "0.1.0"
        },
        role: "operator",
        auth: { token: this.config.gateway.token },
        device: {
          id: this.identity.deviceId,
          publicKey: this.identity.publicKeyBase64Url,
          signature,
          signedAt: signedAtMs,
          nonce
        },
        scopes: ["operator.admin"],
        caps: ["tool-events"]
      }
    }));
  }

  async call(method, params = {}) {
    if (!this.connected) throw new Error("Not connected to gateway");

    const id = `rpc-${++this.reqId}`;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`RPC timeout: ${method}`));
      }, 30000);

      this.pendingRequests.set(id, {
        resolve: (p) => { clearTimeout(timeout); resolve(p); },
        reject:  (e) => { clearTimeout(timeout); reject(e); }
      });

      this.ws.send(JSON.stringify({ type: "req", id, method, params }));
    });
  }

  sendChat(message, sessionKey) {
    if (!this.connected) return null;

    const id = `chat-${++this.reqId}`;
    const idempotencyKey = "window-" + Date.now() + "-" + Math.random().toString(36).substring(2, 8);
    console.log("[gateway] Sending chat.send id=" + id + ": " + message.substring(0, 80));
    this.ws.send(JSON.stringify({
      type: "req",
      id,
      method: "chat.send",
      params: { message, sessionKey, idempotencyKey }
    }));
    return id;
  }

  isConnected() { return this.connected; }

  close() {
    if (this.reconnectTimer) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null; }
    if (this.ws) { this.ws.close(); this.ws = null; }
  }
}
GATEWAYJS

# ============================================================================
# Write bridge.js — Protocol translator
# ============================================================================

cat > "$INSTALL_DIR/bridge.js" << 'BRIDGEJS'
/**
 * Protocol translation: OpenClaw Gateway events -> Window Protocol events.
 *
 * Consolidates all tool calls in a single run into ONE task card.
 * Each tool call becomes a step within that card.
 */

import crypto from "node:crypto";

// --- Human-friendly tool title extraction ---

function extractSearchQuery(urlStr) {
  try {
    const url = new URL(urlStr);
    for (const key of ["q", "query", "search", "text", "search_query"]) {
      const val = url.searchParams.get(key);
      if (val) return val.replace(/\+/g, " ");
    }
  } catch {}
  return null;
}

function extractDomain(urlStr) {
  try { return new URL(urlStr).hostname.replace(/^www\./, ""); } catch {}
  return null;
}

function extractUrl(str) {
  const match = str.match(/https?:\/\/[^\s"'|>]+/);
  return match ? match[0] : null;
}

function friendlyStepName(name, args) {
  if (name === "browser") {
    const url = args?.targetUrl || args?.url || "";
    const query = extractSearchQuery(url);
    const domain = extractDomain(url);
    if (query) return "Searching for " + query;
    if (domain) return "Browsing " + domain;
    if (args?.action === "screenshot") return "Taking a screenshot";
    if (args?.action === "click") return "Interacting with page";
    return "Browsing the web";
  }

  if (name === "exec") {
    const cmd = args?.command || args?.cmd || "";
    if (cmd.includes("curl")) {
      const url = extractUrl(cmd);
      if (url) {
        const query = extractSearchQuery(url);
        if (query) return "Searching for " + query;
        const domain = extractDomain(url);
        if (domain) return "Fetching from " + domain;
      }
      return "Fetching data";
    }
    if (cmd.includes("python") || cmd.includes("node")) return "Running a script";
    if (cmd.includes("git")) return "Running git command";
    return "Running a command";
  }

  if (name === "read_file" || name === "readFile") return "Reading a file";
  if (name === "write_file" || name === "writeFile") return "Writing a file";
  if (name === "edit_file" || name === "editFile") return "Editing a file";
  if (name === "search" || name === "web_search") return "Searching the web";
  if (name === "think" || name === "reasoning") return "Thinking";

  return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Working";
}

export class Bridge {
  constructor() {
    this.activeRuns = new Map();
    this._pendingChat = null;
  }

  registerRun(chatReqId, clientMsgId, runId) {
    this.activeRuns.set(runId, {
      chatReqId, clientMsgId, content: "",
      taskId: null, steps: [], toolMap: new Map(),
    });
    console.log("[bridge] Registered run:", runId);
  }

  processEvent(msg) {
    if (msg.type !== "event" || msg.event !== "agent") return [];
    const p = msg.payload;
    if (!p || !p.runId) return [];
    const run = this.activeRuns.get(p.runId);
    if (!run) return [];

    switch (p.stream) {
      case "assistant": return this._handleAssistant(run, p);
      case "tool":      return this._handleTool(run, p);
      case "lifecycle": return this._handleLifecycle(run, p);
      default:          return [];
    }
  }

  _handleAssistant(run, payload) {
    const data = payload.data || {};
    if (!data.delta) return [];
    run.content += data.delta;
    return [{ type: "message.stream", reply_to: run.clientMsgId, delta: data.delta }];
  }

  _handleTool(run, payload) {
    const events = [];
    const data = payload.data || {};
    const toolCallId = data.toolCallId || data.id || ("tool-" + payload.seq);

    if (data.phase === "start") {
      const stepName = friendlyStepName(data.name, data.args);

      if (!run.taskId) {
        run.taskId = "task_" + crypto.randomBytes(4).toString("hex");
        run.steps = [{ name: stepName, status: "in_progress" }];
        run.toolMap.set(toolCallId, 0);
        events.push({
          type: "task.created", task_id: run.taskId, title: "Researching",
          status: "in_progress", progress: 0.0,
          steps: run.steps.map(s => ({ name: s.name, status: s.status })),
          show_progress: true,
        });
      } else {
        run.steps.push({ name: stepName, status: "in_progress" });
        run.toolMap.set(toolCallId, run.steps.length - 1);
        const done = run.steps.filter(s => s.status === "completed").length;
        events.push({
          type: "task.updated", task_id: run.taskId,
          progress: done / run.steps.length,
          steps: run.steps.map(s => ({ name: s.name, status: s.status })),
        });
      }
    }

    if (data.phase === "result") {
      const idx = run.toolMap.get(toolCallId);
      if (idx !== undefined && run.steps[idx]) {
        run.steps[idx].status = data.isError ? "failed" : "completed";
        const done = run.steps.filter(s => s.status === "completed" || s.status === "failed").length;
        events.push({
          type: "task.updated", task_id: run.taskId,
          progress: done / run.steps.length,
          steps: run.steps.map(s => ({ name: s.name, status: s.status })),
        });
      }
    }

    return events;
  }

  _handleLifecycle(run, payload) {
    const events = [];
    const data = payload.data || {};

    if (data.phase === "start") {
      events.push({ type: "status.update", status: "busy", context_remaining: 1.0, tokens_used: 0 });
    }

    if (data.phase === "end" || data.phase === "error") {
      if (run.taskId) {
        events.push({ type: "task.completed", task_id: run.taskId, progress: 1.0, result: "Completed" });
      }
      if (run.content) {
        events.push({
          type: "message.complete", reply_to: run.clientMsgId,
          id: "msg_" + crypto.randomBytes(6).toString("hex"),
          content: run.content, timestamp: new Date().toISOString(),
        });
      }
      const usage = data.usage || data.result?.usage;
      const tokensUsed = usage?.prompt_tokens || usage?.totalTokens || 0;
      events.push({
        type: "status.update", status: "idle",
        context_remaining: tokensUsed > 0 ? Math.max(0, 1.0 - tokensUsed / 200000) : 1.0,
        tokens_used: tokensUsed,
      });
      this.activeRuns.delete(payload.runId);
    }

    return events;
  }

  reset() { this.activeRuns.clear(); this._pendingChat = null; }
}
BRIDGEJS

# ============================================================================
# Write server.js — Window Protocol HTTP + WebSocket server
# ============================================================================

cat > "$INSTALL_DIR/server.js" << 'SERVERJS'
/**
 * Window Protocol server for OpenClaw.
 * Exposes HTTP + WebSocket on a public port, bridges to OpenClaw Gateway internally.
 */

import http from "node:http";
import fs from "node:fs";
import { WebSocketServer, WebSocket } from "ws";
import { GatewayClient } from "./gateway.js";
import { Bridge } from "./bridge.js";

const config = JSON.parse(fs.readFileSync(new URL("./config.json", import.meta.url), "utf8"));

const VERSION = "0.1.0";
const bridge = new Bridge();
const gateway = new GatewayClient(config);

const clients = new Map();

let agentStatus = "idle";
let tokensUsed = 0;
let contextRemaining = 1.0;

// --- HTTP Server ---

const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }

  if (!checkAuth(req)) {
    res.writeHead(401, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Unauthorized" }));
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname === "/status" && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      agent: config.agent.name, status: agentStatus,
      context_remaining: contextRemaining, tokens_used: tokensUsed, version: VERSION,
    }));
    return;
  }

  if (url.pathname === "/messages" && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ messages: [] }));
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

// --- WebSocket Server ---

const wss = new WebSocketServer({ noServer: true });

server.on("upgrade", (req, socket, head) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname !== "/ws") { socket.destroy(); return; }

  const token = url.searchParams.get("token");
  if (token !== config.window.apiKey) {
    socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    const chatId = url.searchParams.get("chat_id") || "default";
    wss.emit("connection", ws, req, chatId);
  });
});

wss.on("connection", (ws, req, chatId) => {
  console.log("[window] Client connected:", chatId);
  clients.set(ws, { chatId });

  sendToClient(ws, {
    type: "connected", agent: config.agent.name, status: agentStatus,
    context_remaining: contextRemaining, tokens_used: tokensUsed,
  });

  ws.on("message", (data) => {
    try {
      handleClientMessage(ws, chatId, JSON.parse(data.toString()));
    } catch (e) {
      console.error("[window] Parse error:", e.message);
    }
  });

  ws.on("close", () => {
    console.log("[window] Client disconnected:", chatId);
    clients.delete(ws);
  });
});

function handleClientMessage(ws, chatId, msg) {
  if (msg.type === "message.send") {
    console.log("[window] Message from " + chatId + ": " + (msg.content || "").substring(0, 80));

    if (!gateway.isConnected()) {
      sendToClient(ws, {
        type: "message.complete", reply_to: msg.id, id: "msg_err_" + Date.now(),
        content: "Bridge is not connected to OpenClaw Gateway. Please try again shortly.",
        timestamp: new Date().toISOString(),
      });
      return;
    }

    agentStatus = "busy";
    broadcast({ type: "status.update", status: "busy", context_remaining: contextRemaining, tokens_used: tokensUsed });

    const chatReqId = gateway.sendChat(msg.content, config.agent.sessionKey);
    if (chatReqId) {
      bridge._pendingChat = { chatReqId, clientMsgId: msg.id };
    }
  }
}

// --- Gateway Event Handling ---

gateway.on("connected", () => { console.log("[bridge] Gateway connected, bridge is ready"); });
gateway.on("disconnected", () => { console.log("[bridge] Gateway disconnected"); });

gateway.on("gateway-event", (msg) => {
  if (msg.type === "res" && msg.id?.startsWith("chat-")) {
    if (bridge._pendingChat && bridge._pendingChat.chatReqId === msg.id) {
      if (msg.ok) {
        const runId = msg.payload?.runId;
        if (runId) {
          bridge.registerRun(msg.id, bridge._pendingChat.clientMsgId, runId);
          console.log("[bridge] Run registered: " + runId + " for msg " + bridge._pendingChat.clientMsgId);
        }
      } else {
        console.error("[bridge] chat.send failed:", msg.error?.message || "unknown error");
        broadcast({
          type: "message.complete", reply_to: bridge._pendingChat.clientMsgId,
          id: "msg_err_" + Date.now(),
          content: "Error from OpenClaw: " + (msg.error?.message || "unknown error"),
          timestamp: new Date().toISOString(),
        });
        agentStatus = "idle";
        broadcast({ type: "status.update", status: "idle", context_remaining: contextRemaining, tokens_used: tokensUsed });
      }
      bridge._pendingChat = null;
    }
    return;
  }

  const windowEvents = bridge.processEvent(msg);
  for (const evt of windowEvents) {
    if (evt.type === "status.update") {
      agentStatus = evt.status;
      if (evt.tokens_used > 0) tokensUsed = evt.tokens_used;
      if (evt.context_remaining !== undefined) contextRemaining = evt.context_remaining;
    }
    broadcast(evt);
  }
});

// --- Helpers ---

function checkAuth(req) {
  const auth = req.headers.authorization;
  if (!auth) return false;
  const [scheme, token] = auth.split(" ");
  return scheme === "Bearer" && token === config.window.apiKey;
}

function sendToClient(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}

function broadcast(data) {
  const json = JSON.stringify(data);
  for (const [ws] of clients) {
    if (ws.readyState === WebSocket.OPEN) ws.send(json);
  }
}

// --- Start ---

gateway.connect();

server.listen(config.window.port, config.window.host, () => {
  console.log("[window] Bridge listening on http://" + config.window.host + ":" + config.window.port);
  console.log("[window] API key: " + config.window.apiKey.substring(0, 8) + "...");
  console.log("[window] Gateway: " + config.gateway.url);
});
SERVERJS

# ============================================================================
# Install dependencies
# ============================================================================

info "Installing dependencies..."
cd "$INSTALL_DIR"
npm install --production --silent 2>&1
ok "Dependencies installed"

# ============================================================================
# Set up systemd service
# ============================================================================

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << SYSTEMD
[Unit]
Description=Window Protocol Bridge for OpenClaw
After=network.target openclaw.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$(which node) $INSTALL_DIR/server.js
Restart=always
RestartSec=5
StandardOutput=append:$INSTALL_DIR/bridge.log
StandardError=append:$INSTALL_DIR/bridge.log

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" --quiet
ok "Systemd service created and enabled"

# ============================================================================
# Start the bridge
# ============================================================================

info "Starting bridge..."
systemctl start "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
  ok "Bridge is running"
else
  fail "Bridge failed to start. Check logs: journalctl -u $SERVICE_NAME"
fi

# Verify gateway connection
if grep -q "Connected to OpenClaw Gateway" "$INSTALL_DIR/bridge.log" 2>/dev/null; then
  ok "Connected to OpenClaw Gateway"
else
  warn "Gateway connection not confirmed yet. Check logs: tail -f $INSTALL_DIR/bridge.log"
fi

# ============================================================================
# Detect public IP
# ============================================================================

PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "<your-server-ip>")

# ============================================================================
# Print success
# ============================================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Window Bridge installed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${BOLD}Connect from the Window iOS app:${NC}"
echo ""
echo -e "  Host:     ${CYAN}http://${PUBLIC_IP}:${BRIDGE_PORT}${NC}"
echo -e "  API Key:  ${CYAN}${API_KEY}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo ""
echo "  Status:   systemctl status $SERVICE_NAME"
echo "  Logs:     tail -f $INSTALL_DIR/bridge.log"
echo "  Restart:  systemctl restart $SERVICE_NAME"
echo "  Stop:     systemctl stop $SERVICE_NAME"
echo ""
echo -e "  ${BOLD}Quick test:${NC}"
echo ""
echo "  curl -s -H \"Authorization: Bearer ${API_KEY}\" http://localhost:${BRIDGE_PORT}/status | python3 -m json.tool"
echo ""
