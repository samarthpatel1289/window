import Foundation

struct AgentTask: Identifiable, Equatable {
    let id: String
    var title: String
    var status: TaskStatus
    var progress: Double   // 0.0 to 1.0
    var steps: [TaskStep]
    var result: String?

    enum TaskStatus: String, Codable {
        case inProgress = "in_progress"
        case completed
        case failed
    }
}
