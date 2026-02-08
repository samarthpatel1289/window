import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case agent
    }

    /// Whether this message is still being streamed (content incomplete)
    var isStreaming: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
    }
}
