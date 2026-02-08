import Foundation

struct AgentStatus: Codable, Equatable {
    let agent: String
    var status: AgentState
    var contextRemaining: Double   // 0.0 to 1.0
    var version: String?

    enum AgentState: String, Codable {
        case idle
        case busy
    }

    enum CodingKeys: String, CodingKey {
        case agent, status, version
        case contextRemaining = "context_remaining"
    }
}
