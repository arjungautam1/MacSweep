import SwiftUI
import AppKit

public struct OptimizeView: View {
    @ObservedObject var appState: AppState
    @StateObject private var optimizer = SystemOptimizerService.shared

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var groupedTasks: [OptimizeTaskGroup: [OptimizeTaskItem]] {
        Dictionary(grouping: optimizer.tasks, by: { $0.group })
    }

    private var selectedTasksCount: Int {
        optimizer.tasks.filter { $0.isSelected }.count
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celestial Hero Header
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.12), Color.purple.opacity(0.06), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.indigo.opacity(0.15), lineWidth: 1)
                        )

                    HStack(spacing: 24) {
                        // Mercury Planet Visual
                        ZStack {
                            Circle()
                                .fill(RadialGradient(
                                    colors: [Color.indigo.opacity(0.4), Color.clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70
                                ))
                                .frame(width: 140, height: 140)

                            if let mercuryImg = AssetLoader.loadNSImage(named: "planet-static-mercury") {
                                Image(nsImage: mercuryImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .indigo.opacity(0.3), radius: 12, x: 0, y: 4)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.indigo)
                            }
                        }

                        // Hero Text & Motto
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mercury tends Optimize")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(NavigationSection.optimize.poem)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .italic()

                            Divider()
                                .padding(.vertical, 4)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Maintenance State")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(optimizer.isRunningOptimization ? "Optimizing..." : (optimizer.lastOptimizedDate != nil ? "System Refreshed" : "10 Tasks Ready"))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(optimizer.lastOptimizedDate != nil ? .green : .primary)
                                }

                                Spacer()

                                Button(action: {
                                    Task {
                                        await optimizer.runAllSelectedOptimizations()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        if optimizer.isRunningOptimization {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text("Optimize Now (\(selectedTasksCount) tasks)")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .tint(.indigo)
                                .disabled(optimizer.isRunningOptimization || selectedTasksCount == 0)
                            }
                        }
                    }
                    .padding(20)
                }

                // Task Groups
                VStack(spacing: 16) {
                    ForEach(OptimizeTaskGroup.allCases) { group in
                        if let tasks = groupedTasks[group], !tasks.isEmpty {
                            groupCard(group: group, tasks: tasks)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func groupCard(group: OptimizeTaskGroup, tasks: [OptimizeTaskItem]) -> some View {
        VStack(spacing: 0) {
            // Group Header
            HStack(spacing: 10) {
                Image(systemName: group.systemIcon)
                    .font(.body)
                    .foregroundColor(.indigo)
                    .frame(width: 22)

                Text(group.rawValue)
                    .font(.headline)

                Spacer()

                Text("\(tasks.count) tasks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Task List
            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { task.isSelected },
                            set: { _ in optimizer.toggleTaskSelection(task.id) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(task.detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Status Badge
                        switch task.status {
                        case .idle:
                            EmptyView()
                        case .running:
                            ProgressView()
                                .controlSize(.small)
                        case .completed(let duration, let note):
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(String(format: "%.2fs", duration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .help(note)
                        case .skipped(let reason):
                            Text("Skipped")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .help(reason)
                        case .failed(let err):
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .help(err)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if task.id != tasks.last?.id {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
