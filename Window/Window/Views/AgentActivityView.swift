import SwiftUI

struct AgentActivityView: View {
    @EnvironmentObject var appState: AppState

    private var tasks: [AgentTask] {
        appState.timeline.compactMap { item in
            if case .task(let task) = item {
                return task
            }
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No active tasks")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tasks will appear here when your agent\nis working on something.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Active tasks first
                let activeTasks = tasks.filter { $0.status == .inProgress }
                let completedTasks = tasks.filter { $0.status == .completed }

                if !activeTasks.isEmpty {
                    Section {
                        ForEach(activeTasks) { task in
                            TaskRowView(task: task)
                        }
                    } header: {
                        sectionHeader("Active", count: activeTasks.count)
                    }
                }

                if !completedTasks.isEmpty {
                    Section {
                        ForEach(completedTasks) { task in
                            TaskRowView(task: task)
                        }
                    } header: {
                        sectionHeader("Completed", count: completedTasks.count)
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())

            Spacer()
        }
    }
}
