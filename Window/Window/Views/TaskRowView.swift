import SwiftUI

struct TaskRowView: View {
    let task: AgentTask
    @State private var isExpanded: Bool

    init(task: AgentTask, defaultExpanded: Bool? = nil) {
        self.task = task
        _isExpanded = State(initialValue: defaultExpanded ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: title + status
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)

                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                statusBadge
            }

            // Progress bar
            ProgressView(value: task.progress)
                .tint(progressColor)

            // Steps (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(task.steps) { step in
                        HStack(spacing: 8) {
                            stepIcon(for: step.status)
                                .frame(width: 16)

                            Text(step.name)
                                .font(.caption)
                                .foregroundStyle(
                                    step.status == .completed ? .secondary : .primary
                                )

                            Spacer()
                        }
                    }
                }
                .padding(.leading, 20)
            }

            // Result (if completed)
            if let result = task.result, task.status == .completed {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var statusBadge: some View {
        Group {
            switch task.status {
            case .inProgress:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
    }

    private var progressColor: Color {
        switch task.status {
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    @ViewBuilder
    private func stepIcon(for status: TaskStep.StepStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.5)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
