import Foundation

// MARK: - Client -> Server

/// The only event the client sends
struct SendMessageEvent: Codable {
    let type: String = "message.send"
    let id: String
    let content: String
}

// MARK: - Server -> Client

/// All possible events the server can send
enum ServerEvent {
    case connected(ConnectedEvent)
    case messageStream(MessageStreamEvent)
    case messageComplete(MessageCompleteEvent)
    case taskCreated(TaskCreatedEvent)
    case taskUpdated(TaskUpdatedEvent)
    case taskCompleted(TaskCompletedEvent)
    case statusUpdate(StatusUpdateEvent)
}

struct ConnectedEvent: Codable {
    let type: String
    let agent: String
    let status: String
    let contextRemaining: Double
    let tokensUsed: Int?

    enum CodingKeys: String, CodingKey {
        case type, agent, status
        case contextRemaining = "context_remaining"
        case tokensUsed = "tokens_used"
    }
}

struct MessageStreamEvent: Codable {
    let type: String
    let replyTo: String
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type, delta
        case replyTo = "reply_to"
    }
}

struct MessageCompleteEvent: Codable {
    let type: String
    let replyTo: String
    let id: String
    let content: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case type, id, content, timestamp
        case replyTo = "reply_to"
    }
}

struct TaskCreatedEvent: Codable {
    let type: String
    let taskId: String
    let title: String
    let status: String
    let progress: Double
    let steps: [TaskStepEvent]
    let visibility: String?
    let showProgress: Bool?

    enum CodingKeys: String, CodingKey {
        case type, title, status, progress, steps, visibility
        case showProgress = "show_progress"
        case taskId = "task_id"
    }
}

struct TaskUpdatedEvent: Codable {
    let type: String
    let taskId: String
    let progress: Double
    let steps: [TaskStepEvent]

    enum CodingKeys: String, CodingKey {
        case type, progress, steps
        case taskId = "task_id"
    }
}

struct TaskCompletedEvent: Codable {
    let type: String
    let taskId: String
    let progress: Double
    let result: String

    enum CodingKeys: String, CodingKey {
        case type, progress, result
        case taskId = "task_id"
    }
}

struct StatusUpdateEvent: Codable {
    let type: String
    let status: String
    let contextRemaining: Double
    let tokensUsed: Int?

    enum CodingKeys: String, CodingKey {
        case type, status
        case contextRemaining = "context_remaining"
        case tokensUsed = "tokens_used"
    }
}

struct TaskStepEvent: Codable {
    let name: String
    let status: String
}

// MARK: - Parsing

enum ServerEventParser {
    static func parse(json: Data) -> ServerEvent? {
        guard let dict = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }

        let decoder = JSONDecoder()

        switch type {
        case "connected":
            guard let event = try? decoder.decode(ConnectedEvent.self, from: json) else { return nil }
            return .connected(event)
        case "message.stream":
            guard let event = try? decoder.decode(MessageStreamEvent.self, from: json) else { return nil }
            return .messageStream(event)
        case "message.complete":
            guard let event = try? decoder.decode(MessageCompleteEvent.self, from: json) else { return nil }
            return .messageComplete(event)
        case "task.created":
            guard let event = try? decoder.decode(TaskCreatedEvent.self, from: json) else { return nil }
            return .taskCreated(event)
        case "task.updated":
            guard let event = try? decoder.decode(TaskUpdatedEvent.self, from: json) else { return nil }
            return .taskUpdated(event)
        case "task.completed":
            guard let event = try? decoder.decode(TaskCompletedEvent.self, from: json) else { return nil }
            return .taskCompleted(event)
        case "status.update":
            guard let event = try? decoder.decode(StatusUpdateEvent.self, from: json) else { return nil }
            return .statusUpdate(event)
        default:
            return nil
        }
    }
}
