import Foundation

struct TaskStep: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    var status: StepStatus

    enum StepStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed
        case failed
    }
}
