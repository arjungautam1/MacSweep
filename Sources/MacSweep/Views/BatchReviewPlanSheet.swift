import SwiftUI
import AppKit

public struct BatchReviewPlanSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCandidateIds: Set<UUID> = []
    @State private var expandedCandidateIds: Set<UUID> = []
    @State private var useTrash: Bool = true
    @State private var showSafetyGuide: Bool = false

    private var allPlanCandidates: [CleanupCandidate] {
        appState.currentPlan?.candidates ?? []
    }

    private var selectedCandidates: [CleanupCandidate] {
        allPlanCandidates.filter { selectedCandidateIds.contains($0.id) }
    }

    private var totalSelectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + $1.size }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Cleanup Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Select items, review consequences, and choose removal options before proceeding.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: { showSafetyGuide = true }) {
                    Label("What Gets Deleted?", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Full Disk Access Warning Banner (if permission missing)
                    if !appState.hasFullDiskAccess {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Full Disk Access Recommended")
                                    .fontWeight(.bold)
                                Text("MacSweep may encounter permission restrictions when cleaning protected directories (~/Library/Safari, Mail, Containers). Grant Full Disk Access in macOS System Settings for complete cleanup.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Open System Settings") {
                                    DiskPermissionService.shared.openFullDiskAccessSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(.top, 2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }

                    // Summary Banner (Dynamic calculation)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimated Reclaimable Space")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(totalSelectedBytes > 0 ? totalSelectedBytes.formattedBytes : "0 B")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(totalSelectedBytes > 0 ? .accentColor : .secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Selected Targets")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(selectedCandidates.count) of \(allPlanCandidates.count) items")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                    )

                    // Running Apps Warning (if any)
                    if let apps = appState.currentPlan?.affectedRunningApps, !apps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Running Applications Detected")
                                    .fontWeight(.bold)
                            }
                            Text("The following applications are currently running and may hold open locks on cache or data files:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(apps, id: \.processIdentifier) { app in
                                HStack {
                                    Text("• \(app.localizedName ?? "App") (PID: \(app.processIdentifier))")
                                        .font(.caption)
                                    Spacer()
                                    Button("Close Gracefully") {
                                        app.terminate()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }

                    // Safety & Removal Options
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Removal Options")
                            .font(.headline)

                        Toggle(isOn: $useTrash) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Move to macOS Trash (Recommended & Recoverable)")
                                    .fontWeight(.semibold)
                                Text("Files can be recovered by right-clicking them in Trash and selecting 'Put Back'. Space is physically freed when you empty the Trash.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        Toggle(isOn: $appState.isDryRunMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dry Run Simulation Mode")
                                    .fontWeight(.semibold)
                                Text("Simulates the entire plan and verifies targets without deleting any files.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        if !useTrash {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Permanent Deletion Selected")
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text("Files will be permanently deleted immediately and cannot be recovered via the Trash.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                    // Target Candidates List with Interactive Controls
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Cleanup Targets (\(selectedCandidates.count) selected)")
                                .font(.headline)

                            Spacer()

                            Button("Select All") {
                                selectedCandidateIds = Set(allPlanCandidates.map { $0.id })
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Deselect All") {
                                selectedCandidateIds.removeAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if allPlanCandidates.isEmpty {
                            Text("No items in cleanup plan.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(allPlanCandidates) { item in
                                    PlanCandidateItemCard(
                                        item: item,
                                        isSelected: selectedCandidateIds.contains(item.id),
                                        isExpanded: expandedCandidateIds.contains(item.id),
                                        onToggleSelect: {
                                            if selectedCandidateIds.contains(item.id) {
                                                selectedCandidateIds.remove(item.id)
                                            } else {
                                                selectedCandidateIds.insert(item.id)
                                            }
                                        },
                                        onToggleExpand: {
                                            if expandedCandidateIds.contains(item.id) {
                                                expandedCandidateIds.remove(item.id)
                                            } else {
                                                expandedCandidateIds.insert(item.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                if selectedCandidates.isEmpty {
                    Text("Select at least 1 item to proceed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    let targetsToClean = selectedCandidates.map { candidate -> CleanupCandidate in
                        var c = candidate
                        c.isSelected = true
                        return c
                    }
                    guard !targetsToClean.isEmpty else { return }

                    let finalPlan = CleanupExecutorService.shared.prepareCleanupPlan(
                        from: targetsToClean,
                        useTrash: useTrash,
                        isDryRun: appState.isDryRunMode
                    )
                    dismiss()
                    appState.executePlan(finalPlan)
                }) {
                    let actionTitle: String = {
                        if appState.isDryRunMode {
                            return "Simulate Cleanup (\(selectedCandidates.count))"
                        } else if useTrash {
                            return "Move to Trash (\(totalSelectedBytes.formattedBytes))"
                        } else {
                            return "Permanently Delete (\(totalSelectedBytes.formattedBytes))"
                        }
                    }()

                    Text(actionTitle)
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(useTrash || appState.isDryRunMode ? .accentColor : .red)
                .disabled(selectedCandidates.isEmpty)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 580, minHeight: 560)
        .sheet(isPresented: $showSafetyGuide) {
            SafetyTransparencySheet()
        }
        .onAppear {
            // Default selection: select all items in plan initially
            selectedCandidateIds = Set(allPlanCandidates.map { $0.id })
            appState.refreshPermissions()
        }
    }
}

public struct PlanCandidateItemCard: View {
    public let item: CleanupCandidate
    public let isSelected: Bool
    public let isExpanded: Bool
    public let onToggleSelect: () -> Void
    public let onToggleExpand: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Checkbox, Name, Badges, Size, Expand Button
            HStack(spacing: 10) {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: item.category.systemIcon)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.callout)
                            .fontWeight(.semibold)

                        // Safety Badge
                        if item.isSafeByDefault {
                            Text("Safe")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                                .foregroundColor(.green)
                        } else {
                            Text("Review Advised")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                                .foregroundColor(.orange)
                        }

                        // Confidence Badge
                        Text(item.confidence.rawValue.capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                            .foregroundColor(.secondary)

                        // Rebuildable Badge
                        if item.isRebuildable {
                            Text("Rebuildable")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                .foregroundColor(.blue)
                        }
                    }

                    Text(item.path.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(item.size.formattedBytes)
                    .font(.callout)
                    .fontWeight(.medium)

                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded Details View
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text("Contents:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(item.whatItContains)
                            .font(.caption)
                    }

                    HStack(alignment: .top) {
                        Text("Why it exists:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(item.whyItExists)
                            .font(.caption)
                    }

                    HStack(alignment: .top) {
                        Text("Consequence:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(item.removalConsequence)
                            .font(.caption)
                            .foregroundColor(item.impactsSignInsOrSettings ? .orange : .primary)
                    }

                    if let step = item.rebuildOrReinstallStep, !step.isEmpty {
                        HStack(alignment: .top) {
                            Text("Rebuilding:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(step)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    HStack {
                        Spacer()
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([item.path])
                        }) {
                            Label("Reveal in Finder", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .padding(.leading, 32)
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
